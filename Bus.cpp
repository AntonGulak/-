#include <iostream>

int main() {
    int passengers;
    std::cout << "Введите количество пассажиров: ";
    std::cin >> passengers;

    int free_seats = 50 - (passengers % 50);
    std::cout << "Свободных мест в последнем автобусе: " << free_seats << std::endl;

    return 0;
}