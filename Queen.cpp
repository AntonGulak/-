#include <iostream>
#include <cmath>

bool can_queen_move(int x1, int y1, int x2, int y2) {
    return x1 == x2 || y1 == y2 || std::abs(x1 - x2) == std::abs(y1 - y2);
}

int main() {
    int x1, y1, x2, y2;
    std::cout << "Введите координаты первой клетки (x1 y1): ";
    std::cin >> x1 >> y1;
    std::cout << "Введите координаты второй клетки (x2 y2): ";
    std::cin >> x2 >> y2;

    if (can_queen_move(x1, y1, x2, y2)) {
        std::cout << "Yes" << std::endl;
    } else {
        std::cout << "No" << std::endl;
    }

    return 0;
}