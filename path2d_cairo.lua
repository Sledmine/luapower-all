--2d path drawing using cairo.

local path = require'path2d'

if not ... then require'path2d_cairo_demo'; return end

local b2_to_b3 = require'path2d_bezier2'.to_bezier3

local function draw_function(cr)
	local cpx, cpy
	local function write(s, ...)
		if s == 'move' then
			cr:move_to(...)
			cpx, cpy = ...
		elseif s == 'close' then
			cr:close_path()
		elseif s == 'line' then
			cr:line_to(...)
			cpx, cpy = ...
		elseif s == 'curve' then
			cr:curve_to(...)
			cpx, cpy = select(5, ...)
		elseif s == 'quad_curve' then
			cr:curve_to(select(3, b2_to_b3(cpx, cpy, ...)))
			cpx, cpy = select(3, ...)
		elseif s == 'text' then
			local x1, y1, font, text = ...
			cr:font_face(font.family or 'Arial')
			cr:font_size(font.size or 12)
			cr:move_to(x1, y1)
			cr:text_path(tostring(text))
			cpx, cpy = nil
		end
	end
	local function draw(path_, mt)
		cr:new_sub_path()
		path.decompose(write, path_, mt)
	end

	return draw
end

return draw_function

