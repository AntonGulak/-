#include <iostream>

int main() {
    int n;
    std::cout << "Введите число N: ";
    std::cin >> n;

    for (int i = n; i > 0; --i) {
        std::cout << i << std::endl;
        if (i % 5 == 0) {
            std::cout << "Beep" << std::endl;
        }
    }

    return 0;
}