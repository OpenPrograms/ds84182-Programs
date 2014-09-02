local vector = {}
local _vector = {
	add = function( self, o )
		return vector.new(
			self.x + o.x,
			self.y + o.y,
			self.z + o.z
		)
	end,
	sub = function( self, o )
		return vector.new(
			self.x - o.x,
			self.y - o.y,
			self.z - o.z
		)
	end,
	mul = function( self, m )
		return vector.new(
			self.x * m,
			self.y * m,
			self.z * m
		)
	end,
	dot = function( self, o )
		return self.x*o.x + self.y*o.y + self.z*o.z
	end,
	cross = function( self, o )
		return vector.new(
			self.y*o.z - self.z*o.y,
			self.z*o.x - self.x*o.z,
			self.x*o.y - self.y*o.x
		)
	end,
	length = function( self )
		return math.sqrt( self.x*self.x + self.y*self.y + self.z*self.z )
	end,
	normalize = function( self )
		return self:mul( 1 / self:length() )
	end,
	round = function( self, nTolerance )
	    nTolerance = nTolerance or 1.0
		return vector.new(
			math.floor( (self.x + (nTolerance * 0.5)) / nTolerance ) * nTolerance,
			math.floor( (self.y + (nTolerance * 0.5)) / nTolerance ) * nTolerance,
			math.floor( (self.z + (nTolerance * 0.5)) / nTolerance ) * nTolerance
		)
	end,
	tostring = function( self )
		return self.x..","..self.y..","..self.z
	end,
}

local vmetatable = {
	__index = _vector,
	__add = _vector.add,
	__sub = _vector.sub,
	__mul = _vector.mul,
	__unm = function( v ) return v:mul(-1) end,
	__tostring = _vector.tostring,
}

function vector.new( x, y, z )
	local v = {
		x = x or 0,
		y = y or 0,
		z = z or 0
	}
	setmetatable( v, vmetatable )
	return v
end

return vector
