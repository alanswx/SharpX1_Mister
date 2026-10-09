// SPDX-License-Identifier: GPL-2.0-only
#include "Vtop.h"
#include <iostream>
#ifndef TEST_BUILD_PROFILE
#define TEST_BUILD_PROFILE 0
#endif
int main() {
    Vtop model;
    model.eval();
    if (!model.ready) return 2;
    std::cout << TEST_BUILD_PROFILE << '\n';
}
