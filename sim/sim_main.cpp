#include <SDL2/SDL.h>

#include <memory>
#include <chrono>

#include <verilated.h>
#include <iostream>

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"

const int screen_width = 800;
const int screen_height = 600;

const int vga_width = 256;
const int vga_height = 192;

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
    contextp->randReset(2);

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
    top->reset_l = !0;
    top->clk = 0;

    SDL_Event e;
    bool quit = false;

    auto tp1 = std::chrono::high_resolution_clock::now();
    auto tp2 = std::chrono::high_resolution_clock::now();

    unsigned char *pixels = new unsigned char[vga_width * vga_height * 4];

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, vga_width, vga_height);

    bool was_vsync = false;
    while (!contextp->gotFinish() && !quit)
    {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);

        while (SDL_PollEvent(&e))
        {
            if (e.type == SDL_QUIT)
            {
                quit = true;
            }
        }

        contextp->timeInc(1);
        top->clk = !top->clk;

        if (!top->clk)
        {
            if (contextp->time() > 1 && contextp->time() < 10)
            {
                top->reset_l = !1; // Assert reset
            }
            else
            {
                top->reset_l = !0; // Deassert reset
            }
        }

        top->eval();

        static size_t ii = 0;

        if (top->clk)
        {
            pixels[ii] = top->red << 4;
            pixels[ii + 1] = top->green << 4;
            pixels[ii + 2] = top->blue << 4;
            pixels[ii + 3] = 255;
            ii = (ii + 4) % (vga_width * vga_height * 4);
        }

        if (top->reset_l && top->clk && top->vsync && !was_vsync)
        {
            was_vsync = true;
            tp2 = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double> duration = tp2 - tp1;
            tp1 = tp2;
            double elapsed_time = duration.count();

            std::cout << "FPS: " << 1.0 / elapsed_time << "\n";

            void *p;
            int pitch;
            SDL_LockTexture(texture, NULL, &p, &pitch);
            assert(pitch == vga_width * 4);
            memcpy(p, pixels, vga_width * vga_height * 4);
            SDL_UnlockTexture(texture);

            // Read outputs
            //VL_PRINTF("[%" VL_PRI64 "d] clk=%x rstl=%x led=%02x\n",
            //          contextp->time(), top->clk, top->reset_l, top->led);

            SDL_RenderCopy(renderer, texture, NULL, NULL);

            int x = 0;
            int y = 0;
            for (int i = 0; i < 8; ++i)
            {
                SDL_Rect r{x, y, 50, 50};
                SDL_SetRenderDrawColor(renderer, 30, (top->led >> (7 - i)) & 1 ? 255 : 30, 30, 255);
                SDL_RenderFillRect(renderer, &r);
                x += 60;
            }

            SDL_RenderPresent(renderer);
        }

        if (!top->vsync)
            was_vsync = false;
    }

    // Final model cleanup
    top->final();

    /*
    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
*/

    SDL_DestroyTexture(texture);

    delete[] pixels;

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
