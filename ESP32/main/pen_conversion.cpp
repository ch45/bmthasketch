// pen_conversion.cpp

#include <string>
#include <deque>

#include "pen_conversion.hpp"

//
// consume a source container of text data to add to a container of pen moves
//
int convert_data(std::deque<std::string> &src_buf, std::deque<Pen_move> &coord_buf) {
    int count = 0;
    while (!src_buf.empty()) {
        bool pen_down;
        int offset = 0;
        std::string str = src_buf.front();
        if (str.compare(offset, 6, "Pen Up") == 0) { // match
            pen_down = false;
            offset += 6;
        } else if (str.compare(offset, 8, "Pen Down") == 0) {
            pen_down = true;
            offset += 8;
        } else {
            break; // discard invalid data
        }

        std::size_t conv;
        offset++; // over the comma
        const int x = std::stoi(str.substr(offset), &conv);

        offset += conv;
        offset++;
        const int y = std::stoi(str.substr(offset));

        Pen_move pm = Pen_move(pen_down, x, y);
        coord_buf.push_back(pm);

        src_buf.pop_front();
        count++;
    }

    return count;
}

