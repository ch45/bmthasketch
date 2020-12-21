// pen_move.cpp

#include "pen_move.hpp"

#include <sstream>

Pen_move::Pen_move(bool pen_down, int x, int y) {
    this->pen_down = pen_down;
    this->x = x;
    this->y = y;
}

std::ostream& operator << (std::ostream &os, const Pen_move &pm) {
    return os << "RX<-ESP32:" << (pm.is_pen_down() ? "Pen Down" : "Pen Up") << "," << pm.get_x() << "," << pm.get_y() << "\n";
}

std::string Pen_move::to_string() const {
    std::stringstream stream;
    stream << (*this);
    return stream.str();
}

