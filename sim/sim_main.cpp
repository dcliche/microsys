#include <SDL2/SDL.h>

#include <memory>
#include <chrono>

#include <verilated.h>
#include <iostream>

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"

const int screen_width = 640;
const int screen_height = 480;

int main(int argc, char **argv, char **env)
{
    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window *window = SDL_CreateWindow(
        "MicroSys",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        screen_width,
        screen_height,
        0);

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);

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

    auto tp1 = std::chrono::system_clock::now();
    auto tp2 = std::chrono::system_clock::now();

    while (!contextp->gotFinish() && !quit)
    {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);

        tp2 = std::chrono::system_clock::now();
        std::chrono::duration<float> duration = tp2 - tp1;
        tp1 = tp2;
        float elapsed_time = duration.count();

        if (contextp->time() % 1000 == 0)
            std::cout << "Simulation clock frequency: " << 2.0 / elapsed_time << " Hz \n";

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

        // Read outputs
        //VL_PRINTF("[%" VL_PRI64 "d] clk=%x rstl=%x led=%02x\n",
        //          contextp->time(), top->clk, top->reset_l, top->led);

        int x = 0;
        int y = 0;
        for (int i = 0; i < 8; ++i)
        {
            SDL_Rect r{x, y, 50, 50};
            SDL_SetRenderDrawColor(renderer, 30, (top->led >> (7 - i)) & 1 ? 255 : 30, 10, 30);
            SDL_RenderFillRect(renderer, &r);
            x += 60;
        }

        SDL_RenderPresent(renderer);
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

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
