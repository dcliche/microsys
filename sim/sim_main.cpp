#include <SDL.h>

#include <memory>
#include <chrono>

#include <verilated.h>
#include <iostream>
#include <thread>
#include <condition_variable>
#include <atomic>

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"

// 68k simulator
#include "m68k.h"

Vtop *top;
std::atomic<int> assert_xosera_strobe_counter{0};
bool is_booting = false;
bool is_m68k_reset = false;
bool is_m68k_running = true;

std::mutex top_m;

unsigned int timer_100hz = 0;

// ---------------------------------------------------------

void disassemble_program();

/* Memory-mapped IO ports */
#define XOSERA_ADDRESS_START 0xf80060
#define XOSERA_ADDRESS_END (XOSERA_ADDRESS_START + 0x40)

/* IRQ connections */
#define IRQ_NMI_DEVICE 7
#define IRQ_XOSERA_DEVICE 1 // TODO

/* Time between characters sent to output device (seconds) */
//#define OUTPUT_DEVICE_PERIOD 1

/* ROM and RAM sizes */
#define MAX_RAM (1024 * 1024 - 1)

/* Read/write macros */
#define READ_BYTE(BASE, ADDR) (BASE)[ADDR]
#define READ_WORD(BASE, ADDR) (((BASE)[ADDR] << 8) | \
							   (BASE)[(ADDR) + 1])
#define READ_LONG(BASE, ADDR) (((BASE)[ADDR] << 24) |       \
							   ((BASE)[(ADDR) + 1] << 16) | \
							   ((BASE)[(ADDR) + 2] << 8) |  \
							   (BASE)[(ADDR) + 3])

#define WRITE_BYTE(BASE, ADDR, VAL) (BASE)[ADDR] = (VAL)&0xff
#define WRITE_WORD(BASE, ADDR, VAL)     \
	(BASE)[ADDR] = ((VAL) >> 8) & 0xff; \
	(BASE)[(ADDR) + 1] = (VAL)&0xff
#define WRITE_LONG(BASE, ADDR, VAL)            \
	(BASE)[ADDR] = ((VAL) >> 24) & 0xff;       \
	(BASE)[(ADDR) + 1] = ((VAL) >> 16) & 0xff; \
	(BASE)[(ADDR) + 2] = ((VAL) >> 8) & 0xff;  \
	(BASE)[(ADDR) + 3] = (VAL)&0xff

/* Prototypes */
void exit_error(char *fmt, ...);

unsigned int cpu_read_byte(unsigned int address);
unsigned int cpu_read_word(unsigned int address);
unsigned int cpu_read_long(unsigned int address);
void cpu_write_byte(unsigned int address, unsigned int value);
void cpu_write_word(unsigned int address, unsigned int value);
void cpu_write_long(unsigned int address, unsigned int value);
void cpu_pulse_reset(void);
void cpu_set_fc(unsigned int fc);
int cpu_irq_ack(int level);

void nmi_device_reset(void);
void nmi_device_update(void);
int nmi_device_ack(void);

void xosera_device_reset(void);
void xosera_device_update(void);
int xosera_device_ack(void);
unsigned int xosera_device_read(unsigned int address);
void xosera_device_write(unsigned int address, unsigned int value);

void int_controller_set(unsigned int value);
void int_controller_clear(unsigned int value);

/* Data */
unsigned int g_quit = 0; /* 1 if we want to quit */
unsigned int g_nmi = 0;	 /* 1 if nmi pending */

//unsigned int g_output_device_ready = 0;         /* 1 if output device is ready */
//time_t       g_output_device_last_output;       /* Time of last char output */

unsigned int g_int_controller_pending = 0;	   /* list of pending interrupts */
unsigned int g_int_controller_highest_int = 0; /* Highest pending interrupt */

unsigned char g_ram[MAX_RAM + 1]; /* RAM */
unsigned int g_fc;				  /* Current function code from CPU */

/* Exit with an error message.  Use printf syntax. */
void exit_error(const char *fmt, ...)
{
	static int guard_val = 0;
	char buff[100];
	unsigned int pc;
	va_list args;

	if (guard_val)
		return;
	else
		guard_val = 1;

	va_start(args, fmt);
	vfprintf(stderr, fmt, args);
	va_end(args);
	fprintf(stderr, "\n");
	pc = m68k_get_reg(NULL, M68K_REG_PPC);
	m68k_disassemble(buff, pc, M68K_CPU_TYPE_68000);
	fprintf(stderr, "At %04x: %s\n", pc, buff);

	exit(EXIT_FAILURE);
}

/* Read data from RAM, ROM, or a device */
unsigned int cpu_read_byte(unsigned int address)
{
	if (address >= XOSERA_ADDRESS_START && address < XOSERA_ADDRESS_END)
		return xosera_device_read(address - XOSERA_ADDRESS_START);

	/* Otherwise it's data space */
	if (address > MAX_RAM)
		exit_error("Attempted to read byte from RAM address %08x", address);
	return READ_BYTE(g_ram, address);
}

unsigned int cpu_read_word(unsigned int address)
{
	if (is_booting)
	{
		const unsigned int w[] = {0x0010, 0x0000, 0x0000, 0x2000};
		return w[address / 2];
	}

	if (address >= XOSERA_ADDRESS_START && address < XOSERA_ADDRESS_END)
		return xosera_device_read(address - XOSERA_ADDRESS_START);

	/* Otherwise it's data space */
	if (address > MAX_RAM)
		exit_error("Attempted to read word from RAM address %08x", address);
	return READ_WORD(g_ram, address);
}

unsigned int cpu_read_long(unsigned int address)
{
	if (address == 0x414)
		return 0x100000;

	if (address == 0x40c)
		return timer_100hz;

	if (address >= XOSERA_ADDRESS_START && address < XOSERA_ADDRESS_END)
		return xosera_device_read(address - XOSERA_ADDRESS_START);

	/* Otherwise it's data space */
	if (address > MAX_RAM)
		exit_error("Attempted to read long from RAM address %08x", address);
	return READ_LONG(g_ram, address);
}

unsigned int cpu_read_word_dasm(unsigned int address)
{
	if (address > MAX_RAM)
		exit_error("Disassembler attempted to read word from RAM address %08x", address);
	return READ_WORD(g_ram, address);
}

unsigned int cpu_read_long_dasm(unsigned int address)
{
	if (address > MAX_RAM)
		exit_error("Dasm attempted to read long from RAM address %08x", address);
	return READ_LONG(g_ram, address);
}

/* Write data to RAM or a device */
void cpu_write_byte(unsigned int address, unsigned int value)
{
	if (address >= XOSERA_ADDRESS_START && address < XOSERA_ADDRESS_END)
	{
		xosera_device_write(address - XOSERA_ADDRESS_START, value & 0xff);
		return;
	}

	/* Otherwise it's data space */
	if (address > MAX_RAM)
		exit_error("Attempted to write %02x to RAM address %08x", value & 0xff, address);
	WRITE_BYTE(g_ram, address, value);
}

void cpu_write_word(unsigned int address, unsigned int value)
{
	if (address >= XOSERA_ADDRESS_START && address < XOSERA_ADDRESS_END)
	{
		xosera_device_write(address - XOSERA_ADDRESS_START, value & 0xffff);
		return;
	}

	/* Otherwise it's data space */
	if (address > MAX_RAM)
		exit_error("Attempted to write %04x to RAM address %08x", value & 0xffff, address);
	WRITE_WORD(g_ram, address, value);
}

void cpu_write_long(unsigned int address, unsigned int value)
{
	if (address >= XOSERA_ADDRESS_START && address < XOSERA_ADDRESS_END)
	{
		xosera_device_write(address - XOSERA_ADDRESS_START, value);
		return;
	}

	/* Otherwise it's data space */
	if (address > MAX_RAM)
		exit_error("Attempted to write %08x to RAM address %08x", value, address);
	WRITE_LONG(g_ram, address, value);
}

/* Called when the CPU pulses the RESET line */
void cpu_pulse_reset(void)
{
	nmi_device_reset();
	xosera_device_reset();
}

/* Called when the CPU changes the function code pins */
void cpu_set_fc(unsigned int fc)
{
	g_fc = fc;
}

/* Called when the CPU acknowledges an interrupt */
int cpu_irq_ack(int level)
{
	switch (level)
	{
	case IRQ_NMI_DEVICE:
		return nmi_device_ack();
	case IRQ_XOSERA_DEVICE:
		return xosera_device_ack();
	}
	return M68K_INT_ACK_SPURIOUS;
}

/* Implementation for the NMI device */
void nmi_device_reset(void)
{
	g_nmi = 0;
}

void nmi_device_update(void)
{
	if (g_nmi)
	{
		g_nmi = 0;
		int_controller_set(IRQ_NMI_DEVICE);
	}
}

int nmi_device_ack(void)
{
	printf("\nNMI\n");
	fflush(stdout);
	int_controller_clear(IRQ_NMI_DEVICE);
	return M68K_INT_ACK_AUTOVECTOR;
}

/* Implementation for the output device */
void xosera_device_reset(void)
{
	//g_output_device_last_output = time(NULL);
	//g_output_device_ready = 0;
	int_controller_clear(IRQ_XOSERA_DEVICE);
}

void xosera_device_update(void)
{
	/*
	if(!g_output_device_ready)
	{
		if((time(NULL) - g_output_device_last_output) >= OUTPUT_DEVICE_PERIOD)
		{
			g_output_device_ready = 1;
			int_controller_set(IRQ_OUTPUT_DEVICE);
		}
	}
	*/
}

int xosera_device_ack(void)
{
	return M68K_INT_ACK_AUTOVECTOR;
}

unsigned int xosera_device_read(unsigned int address)
{
	while (assert_xosera_strobe_counter > 0 && is_m68k_running)
		std::this_thread::sleep_for(std::chrono::microseconds(1));

	top_m.lock();
	top->xosera_reg_num = address >> 2;
	top->xosera_bytesel = address & 0x2 ? 1 : 0;
	top->xosera_rd_nwr = 1;
	top->xosera_cs_n = 0;
	top_m.unlock();

	assert_xosera_strobe_counter = 4;
	while (assert_xosera_strobe_counter > 0 && is_m68k_running)
		std::this_thread::sleep_for(std::chrono::microseconds(1));

	unsigned int value;
	top_m.lock();
	value = top->xosera_data_out;
	top_m.unlock();

	int_controller_clear(IRQ_XOSERA_DEVICE);

	//printf("Xosera read: address=%x, value=%x, reg_num=%x, bytesel=%x\n", address, value, top->xosera_reg_num, top->xosera_bytesel);

	return value;
}

void xosera_device_write(unsigned int address, unsigned int value)
{
	while (assert_xosera_strobe_counter > 0 && is_m68k_running)
		std::this_thread::sleep_for(std::chrono::microseconds(1));

	top_m.lock();
	top->xosera_reg_num = address >> 2;
	top->xosera_bytesel = address & 0x2 ? 1 : 0;
	top->xosera_data_in = value & 0xff;
	top->xosera_rd_nwr = 0;
	top->xosera_cs_n = 0;
	assert_xosera_strobe_counter = 4;
	top_m.unlock();
	//printf("Xosera write: address=%x, value=%x, reg_num=%x, bytesel=%x, data_in=%x\n", address, value, top->xosera_reg_num, top->xosera_bytesel, top->xosera_data_in);
}

/* Implementation for the interrupt controller */
void int_controller_set(unsigned int value)
{
	unsigned int old_pending = g_int_controller_pending;

	g_int_controller_pending |= (1 << value);

	if (old_pending != g_int_controller_pending && value > g_int_controller_highest_int)
	{
		g_int_controller_highest_int = value;
		m68k_set_irq(g_int_controller_highest_int);
	}
}

void int_controller_clear(unsigned int value)
{
	g_int_controller_pending &= ~(1 << value);

	for (g_int_controller_highest_int = 7; g_int_controller_highest_int > 0; g_int_controller_highest_int--)
		if (g_int_controller_pending & (1 << g_int_controller_highest_int))
			break;

	m68k_set_irq(g_int_controller_highest_int);
}

void cpu_instr_callback(int pc)
{
	(void)pc;
}

// ---------------------------------------------------------

const int screen_width = 1024;
const int screen_height = 768;

const int vga_width = 800;
const int vga_height = 525;

double sc_time_stamp()
{
	return 0.0;
}

void m68k()
{
	printf("m68k thread started.\n");
	m68k_init();
	m68k_set_cpu_type(M68K_CPU_TYPE_68000);

	while (is_m68k_running)
	{
		//std::unique_lock<std::mutex> lk(m68k_cv_m);
		//m68k_cv.wait(lk);
		if (is_m68k_reset)
		{
			is_m68k_reset = false;
			is_booting = true;
			m68k_pulse_reset();
			is_booting = false;
		}
		else
		{
			m68k_execute(100);
		}
	}
	printf("m68k thread exited.\n");
}

int main(int argc, char **argv, char **env)
{
	const char *program_file = "test.bin";

	FILE *fhandle;

	SDL_Init(SDL_INIT_VIDEO);

	SDL_Window *window = SDL_CreateWindow(
		"MicroSys",
		SDL_WINDOWPOS_UNDEFINED_DISPLAY(1),
		SDL_WINDOWPOS_UNDEFINED,
		screen_width,
		screen_height,
		0);

	SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

	// Create logs/ directory in case we have traces to put under it
	Verilated::mkdir("logs");

	// Construct a VerilatedContext to hold simulation time, etc.
	// Multiple modules (made later below with Vtop) may share the same
	// context to share time, or modules may have different contexts if
	// they should be independent from each other.

	// Using unique_ptr is similar to
	// "VerilatedContext* contextp = new VerilatedContext" then deleting at end.
	const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

	// Set debug level, 0 is off, 9 is highest presently used
	// May be overridden by commandArgs argument parsing
	contextp->debug(0);

	// Randomization reset policy
	// May be overridden by commandArgs argument parsing
	contextp->randReset(0);

	// Verilator must compute traced signals
	contextp->traceEverOn(true);

	// Pass arguments so Verilated code can see them, e.g. $value$plusargs
	// This needs to be called before you create any model
	contextp->commandArgs(argc, argv);

	// Construct the Verilated model, from Vtop.h generated from Verilating "top.v".
	// Using unique_ptr is similar to "Vtop* top = new Vtop" then deleting at end.
	// "TOP" will be the hierarchical name of the module.
	top = new Vtop{contextp.get(), "TOP"};

	// Set Vtop's input signals
	top->reset = 1;
	top->clk = 0;
	top->xosera_cs_n = 1;
	top->xosera_rd_nwr = 1;

	SDL_Event e;
	bool quit = false;

	auto tp_frame = std::chrono::high_resolution_clock::now();
	auto tp_timer = std::chrono::high_resolution_clock::now();
	auto tp_clk = std::chrono::high_resolution_clock::now();
	auto tp_now = std::chrono::high_resolution_clock::now();
	std::chrono::duration<double> duration_clk;

	const size_t pixels_size = vga_width * vga_height * 4;
	unsigned char *pixels = new unsigned char[pixels_size];

	SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, vga_width, vga_height);

	unsigned int frame_counter = 0;
	bool was_vsync = false;

	size_t pixel_index = 0;

	bool manual_reset = 0;

	bool deassert_xosera_strobe = false;

	std::thread *m68k_thread = nullptr;

	bool was_loaded = false;

	while (!contextp->gotFinish() && !quit)
	{
		if (manual_reset && !was_loaded)
		{
			if (m68k_thread)
			{
				is_m68k_running = false;
				m68k_thread->join();
			}

			if ((fhandle = fopen(program_file, "rb")) == NULL)
				exit_error("Unable to open");

			memset(g_ram, 0, MAX_RAM + 1);

			if (fread(g_ram + 0x2000, 1, MAX_RAM + 1 - 0x2000, fhandle) <= 0)
				exit_error("Error reading %s", argv[1]);

			fclose(fhandle);

			timer_100hz = 0;
			is_m68k_reset = true;
			is_m68k_running = true;
			m68k_thread = new std::thread(m68k);
			was_loaded = true;
		}

		top_m.lock();

		//std::cout << "PC: " << m68k_get_reg(NULL,M68K_REG_PC) << "\n";

		//SDL_Delay(100);
		//if (contextp->time() > 500)
		//    break;

		contextp->timeInc(1);
		top->clk = 0;
		top->eval();

		contextp->timeInc(1);
		top->clk = 1;

		//if ((contextp->time() % 8 == 0) && !top->reset) {
		//	is_m68k_execute = true;
		//	m68k_cv.notify_one();
		//}

		if (manual_reset || (contextp->time() > 1 && contextp->time() < 10))
		{
			top->reset = 1; // Assert reset
		}
		else
		{
			if (top->reset)
			{
				top->reset = 0; // Deassert reset
				is_m68k_reset = true;
			}
		}

		// Update video display
		if (was_vsync && top->vga_vsync)
		{
			pixel_index = 0;
			was_vsync = false;
		}

		pixels[pixel_index] = top->vga_r << 4;
		pixels[pixel_index + 1] = top->vga_g << 4;
		pixels[pixel_index + 2] = top->vga_b << 4;
		pixels[pixel_index + 3] = 255;
		pixel_index = (pixel_index + 4) % (pixels_size);

		if (!top->vga_vsync && !was_vsync)
		{
			was_vsync = true;
			void *p;
			int pitch;
			SDL_LockTexture(texture, NULL, &p, &pitch);
			assert(pitch == vga_width * 4);
			memcpy(p, pixels, vga_width * vga_height * 4);
			SDL_UnlockTexture(texture);
		}

		tp_now = std::chrono::high_resolution_clock::now();
		std::chrono::duration<double> duration_frame = tp_now - tp_frame;
		std::chrono::duration<double> duration_timer = tp_now - tp_timer;

		if (contextp->time() % 2000000 == 0)
		{
			duration_clk = tp_now - tp_clk;
			tp_clk = tp_now;
		}

		if (duration_timer.count() >= 1.0 / 100.0)
		{
			timer_100hz++;
			tp_timer = tp_now;
		}

		if (duration_frame.count() >= 1.0 / 60.0)
		{
			while (SDL_PollEvent(&e))
			{
				if (e.type == SDL_QUIT)
				{
					quit = true;
				}
				else if (e.type == SDL_KEYUP)
				{
					switch (e.key.keysym.sym)
					{
					case SDLK_F1:
						manual_reset = false;
						std::cout << "Reset released\n";
						break;
					}
				}
				else if (e.type == SDL_KEYDOWN)
				{
					if (e.key.repeat == 0)
					{
						switch (e.key.keysym.sym)
						{
						case SDLK_F1:
							manual_reset = true;
							was_loaded = false;
							std::cout << "Reset pressed\n";
							break;
						}
					}
				}
			}

			int draw_w, draw_h;
			SDL_GL_GetDrawableSize(window, &draw_w, &draw_h);

			int scale_x, scale_y;
			scale_x = draw_w / screen_width;
			scale_y = draw_h / screen_height;

			SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
			SDL_RenderClear(renderer);

			if (frame_counter % 100 == 0)
			{
				std::cout << "Clk speed: " << 1.0 / (duration_clk.count()) << " MHz\n";
			}

			tp_frame = tp_now;
			frame_counter++;

			// Read outputs

			SDL_Rect vga_r = {0, 0, scale_x * screen_width, scale_y * screen_height};
			SDL_RenderCopy(renderer, texture, NULL, &vga_r);

			SDL_RenderPresent(renderer);
		}

		if (assert_xosera_strobe_counter > 0)
		{
			assert_xosera_strobe_counter--;
			if (assert_xosera_strobe_counter == 0)
			{
				top->xosera_cs_n = 1;
				top->xosera_rd_nwr = 1;
			}
		}

		top->eval();

		top_m.unlock();
	}

	is_m68k_running = false;
	m68k_thread->join();

	// Final model cleanup
	top->final();
	delete top;

	SDL_DestroyTexture(texture);

	delete[] pixels;

	SDL_DestroyWindow(window);
	SDL_Quit();

	return 0;
}
