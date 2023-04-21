#include <iostream>
#include <string>

bool is_palindrome(int number) {
    std::string number_str = std::to_string(number);
    int str_length = number_str.length();
    bool is_pal = true;

    for (int i = 0; i < str_length / 2; ++i) {
        if (number_str[i] != number_str[str_length - 1 - i]) {
            is_pal = false;
            break;
        }
    }

    return is_pal;
}

int main() {
    int input;
    std::cout << "Введите число: ";
    std::cin >> input;
    
    if (is_palindrome(input)) {
        std::cout << input << " это палиндром" << std::endl;
    } else {
        std::cout << input << " не является палиндромом" << std::endl;
    }

    return 0;
}