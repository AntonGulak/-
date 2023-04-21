#include <iostream>
#include <vector>
#include <cmath>
#include <algorithm>
#include <iomanip>

struct Point {
    double x, y;
};

double polygon_area(const std::vector<Point> &vertices) {
    double area = 0.0;
    int n = vertices.size();

    for (int i = 0; i < n; ++i) {
        int j = (i + 1) % n;
        area += vertices[i].x * vertices[j].y - vertices[j].x * vertices[i].y;
    }

    return std::abs(area) / 2.0;
}

Point polygon_center(const std::vector<Point> &vertices) {
    Point center{0, 0};
    int n = vertices.size();

    for (int i = 0; i < n; ++i) {
        center.x += vertices[i].x;
        center.y += vertices[i].y;
    }

    center.x /= n;
    center.y /= n;

    return center;
}

bool compare_points_by_angle(const Point &a, const Point &b, const Point &center) {
    double angle_a = std::atan2(a.y - center.y, a.x - center.x);
    double angle_b = std::atan2(b.y - center.y, b.x - center.x);
    return angle_a < angle_b;
}

double calculate_polygon_area(const std::vector<std::vector<double>> &input_points) {
    std::vector<Point> vertices;
    for (const auto &point : input_points) {
        vertices.push_back({point[0], point[1]});
    }

    Point center = polygon_center(vertices);
    std::sort(vertices.begin(), vertices.end(), [&](const Point &a, const Point &b) {
        return compare_points_by_angle(a, b, center);
    });

    return polygon_area(vertices);
}

int main() {
    std::vector<std::vector<double>> input_points = {
        {1.8, 3.6},
        {2.2, 2.3},
        {3.6, 2.4},
        {3.1, 0.5},
        {0.6, 2.1}
    };

    double area = calculate_polygon_area(input_points);
    std::cout << std::fixed << std::setprecision(2);
    std::cout << "Площадь многоугольника: " << area << std::endl;

    return 0;
}