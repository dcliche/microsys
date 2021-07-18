#include <SDL.h>

#include <memory>
#include <chrono>

#include <verilated.h>
#include <iostream>

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"

const int screen_width = 1024;
const int screen_height = 768;

const int vga_width = 800;
const int vga_height = 525;

double sc_time_stamp() {
    return 0.0;
}

int main(int argc, char **argv, char **env)
{
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
    const std::unique_ptr<Vtop> top{new Vtop{contextp.get(), "TOP"}};

    // Set Vtop's input signals
    top->reset = 1;
    top->clk = 0;
    top->sw = 0;

    SDL_Event e;
    bool quit = false;

    auto tp_frame = std::chrono::high_resolution_clock::now();
    auto tp_clk = std::chrono::high_resolution_clock::now();
    auto tp_now = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration_clk;

    const size_t pixels_size = vga_width * vga_height * 4;
    unsigned char *pixels = new unsigned char[pixels_size];

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, vga_width, vga_height);

    unsigned int frame_counter = 0;
    bool was_vsync = false;
    auto last_led = top->led;

    size_t pixel_index = 0;

    bool manual_reset = 0;

    while (!contextp->gotFinish() && !quit)
    {
        //SDL_Delay(100);
        //if (contextp->time() > 500)
        //    break;

        contextp->timeInc(1);
        top->clk = 0;
        top->eval();
        contextp->timeInc(1);
        top->clk = 1;
        if (manual_reset || (contextp->time() > 1 && contextp->time() < 10))
        {
            top->reset = 1; // Assert reset
        }
        else
        {
            top->reset = 0; // Deassert reset
        }

        // Update video display
        if (was_vsync && top->vga_vsync) {
            pixel_index = 0;
            was_vsync = false;
        }

        pixels[pixel_index] = top->vga_r << 4;
        pixels[pixel_index + 1] = top->vga_g << 4;
        pixels[pixel_index + 2] = top->vga_b << 4;
        pixels[pixel_index + 3] = 255;
        pixel_index = (pixel_index + 4) % (pixels_size);

        if (!top->vga_vsync && !was_vsync) {
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

        if (contextp->time() % 2000000 == 0) {
            duration_clk = tp_now - tp_clk;
            tp_clk = tp_now;
        }

        if (duration_frame.count() >= 1.0/60.0)
        {
            while (SDL_PollEvent(&e))
            {
                if (e.type == SDL_QUIT)
                {
                    quit = true;
                } else if (e.type == SDL_KEYUP) {
                    if (e.key.keysym.sym >= SDLK_1 && e.key.keysym.sym <= SDLK_8) {
                        int i = 7 - (e.key.keysym.sym - SDLK_1);
                        unsigned char mask = 0x1 << i;
                        if ((top->sw >> i) & 0x1) {
                            top->sw &= ~mask;
                        } else
                            top->sw |= mask;
                    } else if (e.key.keysym.sym == SDLK_F1) {
                        manual_reset = false;
                        std::cout << "Reset released\n";
                    }
                } else if (e.type == SDL_KEYDOWN) {
                    if (e.key.repeat == 0 && e.key.keysym.sym == SDLK_F1) {
                        manual_reset = true;
                        std::cout << "Reset pressed\n";
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

            if (frame_counter % 100 == 0) {
                std::cout << "Clk speed: " << 1.0 / (duration_clk.count()) << " MHz\n";
            }

            tp_frame = tp_now;
            frame_counter++;

            // Read outputs
            //VL_PRINTF("[%" VL_PRI64 "d] clk=%x rstl=%x led=%02x\n",
            //          contextp->time(), top->clk, top->reset_l, top->led);

            SDL_Rect vga_r = {0, scale_x * (screen_height - vga_height - 1), scale_x * vga_width, scale_y * vga_height};
            SDL_RenderCopy(renderer, texture, NULL, &vga_r);

            int x = 0;
            int y = 0;
            for (int i = 7; i >= 0; --i)
            {
                SDL_Rect r{scale_x * x, scale_y * y, scale_x * 50, scale_y * 50};
                SDL_SetRenderDrawColor(renderer, 30, (top->led >> i) & 1 ? 255 : 30, 30, 255);
                SDL_RenderFillRect(renderer, &r);
                r.y += scale_y * 60;
                SDL_SetRenderDrawColor(renderer, (top->sw >> i) & 1 ? 255 : 30, 30, 30, 255);
                SDL_RenderFillRect(renderer, &r);
                x += 60;
            }

            SDL_RenderPresent(renderer);
        }

        top->eval();
    }

    // Final model cleanup
    top->final();

    SDL_DestroyTexture(texture);

    delete[] pixels;

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
