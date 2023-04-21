#include <iostream>
#include <fstream>
#include <string>

std::string check_braces(const std::string &file_name) {
    std::ifstream input_file(file_name);
    if (!input_file.is_open()) {
        return "не удалось открыть файл.";
    }

    int open_braces = 0;
    int close_braces = 0;
    char ch;

    while (input_file.get(ch)) {
        if (ch == '{') {
            open_braces++;
        } else if (ch == '}') {
            close_braces++;
        }
    }

    input_file.close();

    if (open_braces == close_braces) {
        return "Открывающие и закрывающие фигурные скобки совпадают.";
    } else {
        return "Открывающие и закрывающие фигурные скобки не совпадают.";
    }
}

void write_output(const std::string &file_name, const std::string &content) {
    std::ofstream output_file(file_name);
    if (!output_file.is_open()) {
        std::cerr << "не удалось открыть файл для записи." << std::endl;
        return;
    }

    output_file << content;
    output_file.close();
}

int main() {
    std::string input_file_name;
    std::cout << "Введите имя файла:";
    std::cin >> input_file_name;

    std::string result = check_braces(input_file_name);
    std::cout << result << std::endl;

    std::string output_file_name = "out.txt";
    write_output(output_file_name, result);

    return 0;
}