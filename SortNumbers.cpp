#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>

std::string extract_digits(const std::string &str) {
    std::string digits;
    for (char ch : str) {
        if (std::isdigit(ch)) {
            digits += ch;
        }
    }
    return digits;
}

bool compare_records(const std::string &a, const std::string &b) {
    std::string a_phone = extract_digits(a);
    std::string b_phone = extract_digits(b);
    return a_phone < b_phone;
}

void sort_records(const std::string &input_file_name, const std::string &output_file_name) {
    std::ifstream input_file(input_file_name);
    if (!input_file.is_open()) {
        std::cerr << "не удалось открыть файл для чтения." << std::endl;
        return;
    }

    std::vector<std::string> records;
    std::string line;
    while (std::getline(input_file, line)) {
        records.push_back(line);
    }

    std::sort(records.begin(), records.end(), compare_records);

    std::ofstream output_file(output_file_name);
    if (!output_file.is_open()) {
        std::cerr << "Не удалось открыть файл для записи." << std::endl;
        return;
    }

    for (const std::string &record : records) {
        output_file << record << std::endl;
    }

    input_file.close();
    output_file.close();
}

int main() {
    std::string input_file_name;
    std::cout << "Введите имя файла с записями: ";
    std::cin >> input_file_name;

    std::string output_file_name;
    std::cout << "Введите имя файла для записи отсортированных данных: ";
    std::cin >> output_file_name;

    sort_records(input_file_name, output_file_name);

    return 0;
}