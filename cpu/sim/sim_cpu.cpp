#include <SDL2/SDL.h>

#include <memory>
#include <chrono>

#include <verilated.h>
#include <iostream>

#include "Vmicroaddr_microaddr.h"
#include "Vmicroaddr.h"

struct TestCase
{
    const char *name;
    uint8_t reset;
    uint8_t cmd;
    uint16_t load_addr;
    uint16_t expected_addr;
};

TestCase test_cases[]{
    {"reset", 1, Vmicroaddr_microaddr::cmd::NONE, 0, 0},
    {"inc", 0, Vmicroaddr_microaddr::cmd::INC, 0, 1},
    {"none", 0, Vmicroaddr_microaddr::cmd::NONE, 0, 1},
    {"reset2", 1, Vmicroaddr_microaddr::cmd::NONE, 0, 0},
    {"load", 0, Vmicroaddr_microaddr::cmd::LOAD, 0xFA, 0xFA},
    {"inc", 0, Vmicroaddr_microaddr::cmd::INC, 0, 0xFB},
    {"reset3", 1, Vmicroaddr_microaddr::cmd::INC, 0, 0},
};

int main(int argc, char **argv, char **env)
{
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);
    contextp->randReset(2);
    const std::unique_ptr<Vmicroaddr> top{new Vmicroaddr{contextp.get(), "TOP"}};

    top->clk = 0;
    top->reset = 0;
    top->cmd = Vmicroaddr_microaddr::cmd::NONE;
    top->load_addr = 0;
    top->eval();

    int num_test_cases = sizeof(test_cases) / sizeof(TestCase);

    for (const auto &test_case : test_cases)
    {
        top->cmd = test_case.cmd;
        top->reset = test_case.reset;
        top->load_addr = test_case.load_addr;
        top->eval();

        top->clk = 1;
        top->eval();
        top->clk = 0;
        top->eval();

        if (top->addr == test_case.expected_addr)
        {
            printf("%s passed\n", test_case.name);
        }
        else
        {
            printf("%s fail (expected %04X but was %04X)\n", test_case.name, test_case.expected_addr, top->addr);
        }
    }

    // Final model cleanup
    top->final();

    return 0;
}
