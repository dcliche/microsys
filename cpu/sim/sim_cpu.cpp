#include <SDL2/SDL.h>

#include <memory>
#include <chrono>

#include <verilated.h>
#include <iostream>

#include "Vmicroaddr_microaddr_types.h"
#include "Vmicroaddr.h"

struct TestCase
{
    const char *name;
    uint8_t reset;
    uint8_t zflag;
    uint8_t M;
    uint8_t cmd;
    uint16_t load_addr;
    uint16_t expected_addr;
};

using cmd_t = Vmicroaddr_microaddr_types::cmd_t;

TestCase test_cases[]{
    {"reset", 1, 0, 0, cmd_t::NONE, 0, 0},
    {"inc", 0, 0, 0, cmd_t::INC, 0, 1},
    {"none", 0, 0, 0, cmd_t::NONE, 0, 1},
    {"reset2", 1, 0, 0, cmd_t::NONE, 0, 0},
    {"jmp", 0, 0, 0, cmd_t::JMP, 0xFA, 0xFA},
    {"inc", 0, 0, 0, cmd_t::INC, 0, 0xFB},
    {"reset3", 1, 0, 0, cmd_t::INC, 0, 0},

    {"jmpF", 0, 0, 0, cmd_t::JMP, 0xFFFF, 0x7FF},

    {"reset_call", 1, 0, 0, cmd_t::NONE, 0, 0},
    {"call1", 0, 0, 0, cmd_t::CALL, 0xA0, 0xA0},
    {"ret1", 0, 0, 0, cmd_t::RET, 0, 0x01},

    {"reset4", 1, 0, 0, cmd_t::NONE, 0, 0},
    {"call2.1", 0, 0, 0, cmd_t::CALL, 0xA0, 0xA0},
    {"call2.2", 0, 0, 0, cmd_t::CALL, 0xB0, 0xB0},
    {"ret2.2", 0, 0, 0, cmd_t::RET, 0, 0xA1},
    {"ret2.1", 0, 0, 0, cmd_t::RET, 0, 0x01},

    {"reset5", 1, 0, 0, cmd_t::NONE, 0, 0},
    {"jnz", 0, 1, 0, cmd_t::JNZ, 0xA0, 0x01},
    {"jnz2", 0, 0, 0, cmd_t::JNZ, 0xA0, 0xA0},

    {"opjmp", 0, 0, 1, cmd_t::OPJMP, 0, 0x1AB},
    {"opjmp2", 0, 0, 2, cmd_t::OPJMP, 0, 0x012},
    {"opjmp3", 0, 0, 3, cmd_t::OPJMP, 0, 0}};

bool test_expected_addr(Vmicroaddr *counter, const TestCase &test_case)
{
    if (counter->addr == test_case.expected_addr)
    {
        return true;
    }
    printf("%s: fail: expected addr %08X but was %08X\n",
           test_case.name, test_case.expected_addr,
           counter->addr);
    return false;
}

int main(int argc, char **argv, char **env)
{
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);
    contextp->randReset(2);
    Vmicroaddr *top = new Vmicroaddr{contextp.get(), "TOP"};

    top->clk = 0;
    top->reset = 0;
    top->zflag = 0;
    top->M = 0;
    top->cmd = cmd_t::NONE;
    top->load_addr = 0;
    top->eval();

    int num_test_cases = sizeof(test_cases) / sizeof(TestCase);
    int num_passes = 0;

    for (const auto &test_case : test_cases)
    {
        top->cmd = test_case.cmd;
        top->reset = test_case.reset;
        top->zflag = test_case.zflag;
        top->M = test_case.M;
        top->load_addr = test_case.load_addr;
        top->eval();

        top->clk = 1;
        top->eval();
        top->clk = 0;
        top->eval();

        bool passed = true;
        passed &= test_expected_addr(top, test_case);

        if (passed)
        {
            printf("%s: passed\n", test_case.name);
            num_passes++;
        }
    }

    // Final model cleanup
    top->final();
    delete top;
    printf("\n");
    printf("Tests passed: %d/%d\n", num_passes, num_test_cases);
    return 0;
}
