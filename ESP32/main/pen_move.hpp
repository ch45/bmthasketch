// pen_move.hpp

#ifndef PEN_MOVE_HPP
#define PEN_MOVE_HPP

#include <string>

class Pen_move {
    bool pen_down;
    int x;
    int y;
public:
    Pen_move(bool, int, int);
    bool is_pen_down() const { return pen_down; }
    int get_x() const { return x; }
    int get_y() const { return y; }
    std::string to_string() const;
};

#endif

