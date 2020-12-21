// pen_conversion.hpp

#ifndef PEN_CONVERSION_HPP
#define PEN_CONVERSION_HPP

#include "pen_move.hpp"

#include <deque>
#include <string>

int convert_data(std::deque<std::string> &src_buf, std::deque<Pen_move> &coord_buf);

#endif

