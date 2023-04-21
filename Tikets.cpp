#include <iostream>
#include <vector>
#include <algorithm>

double calculate_price_with_discount(const std::vector<int> &ages) {
    int youngest = *min_element(ages.begin(), ages.end());
    double discount = static_cast<double>(youngest) / 100;
    double total_price = 10.0 * ages.size();
    return total_price * (1 - discount);
}

int main() {
    std::vector<int> ages(5);
    std::cout << "Введите возраст 5 человек, разделенных пробелом: ";
    for (int i = 0; i < 5; ++i) {
        std::cin >> ages[i];
    }

    double price = calculate_price_with_discount(ages);
    std::cout << "Общая стоимость билетов: " << price << " долларов США" << std::endl;

    return 0;
}