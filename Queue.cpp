#include <iostream>
#include <vector>

class Queue {
public:
    Queue() {}

    void add(int client_id) {
        data.push_back(client_id);
    }

    void remove() {
        if (!data.empty()) {
            data.erase(data.begin());
        } else {
            std::cout << "Очередь пуста, нечего удалять." << std::endl;
        }
    }

    void print() const {
        if (!data.empty()) {
            std::cout << "Очередь: ";
            for (int client_id : data) {
                std::cout << client_id << " ";
            }
            std::cout << std::endl;
        } else {
            std::cout << "Очередь пуста." << std::endl;
        }
    }

private:
    std::vector<int> data;
};

int main() {
    Queue q;
    q.add(1);
    q.add(2);
    q.add(3);
    q.print(); // Очередь: 1 2 3

    q.remove();
    q.print(); // Очередь: 2 3

    q.remove();
    q.remove();
    q.print(); // Очередь пуста

    q.remove(); // Очередь пуста, нечего удалять.

    return 0;
}