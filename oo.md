---
tagline: fancy object system
---

## `local oo = require'oo'`

Object system with virtual properties and method overriding hooks.

## In a nutshell

 * single, dynamic inheritance by default:
   * `Fruit = oo.Fruit()`
   * `Apple = oo.Apple(Fruit)`
   * `apple = Apple(...)`
   * `apple.super -> Apple`
   * `Apple.super -> Fruit`
 * multiple, static inheritance by request:
   * `Apple:inherit(Fruit[,replace])` - statically inherit `Fruit`,
	  optionally replacing existing properties.
   * `Apple:detach()` - detach from the parent class, in other words
	  statically inherit `self.super`.
 * virtual properties with getter and setter:
   * reading `Apple.foo` calls `Apple:get_foo()` to get the value, if
	  `Apple.get_foo` is defined.
   * assignment to `Apple.foo` calls `Apple:set_foo(value)` if
	  `Apple.set_foo` is defined.
   * missing the setter, the property is considered read-only and the
	  assignment fails.
 * stored properties (no getter):
   * assignment to `Apple.foo` calls `Apple:set_foo(value)` and sets
	  `Apple.state.foo`.
   * reading `Apple.foo` reads back `Apple.state.foo`.
 * method overriding hooks:
   * `function Apple:before_pick(args...) return newargs... end` makes
	  `Apple:pick()` call your method first.
   * `function Apple:after_pick(ret...) return newret... end` makes
	  `Apple:pick()` call your method last.
   * `function Apple:override_pick(inherited, ...)` lets you override
	  `Apple:pick()` and call `inherited(self, ...)`.
 * events with optional namespace tags:
   * `Apple:on('falling.ns1', function(self, args...) ... end)` - register
	  an event handler
	* `Apple:falling(args...)` - default event handler for the `falling` event
	* `Apple:fire('falling', args...)` - call all `falling` event handlers
	* `Apple:off'falling'` - remove all `falling` event handlers
	* `Apple:off'.ns1'` - remove all event handlers on the `ns1` namespace
 * introspection:
   * `self:allpairs() -> iterator() -> name, value, source` - iterate all
	  properties, including inherited _and overriden_ ones.
   * `self:properties()` -> get a table of all current properties and values,
	  including inherited ones.
   * `self:inspect()` - inspect the class/instance structure and contents in
	  detail (requires [glue]).
 * overridable subclassing and instantiation mechanisms:
   * `Fruit = oo.Fruit()` is sugar for `Fruit = oo.Object:subclass()`
   * `Apple = oo.Apple(Fruit)` is sugar for `Apple = Fruit:subclass()`
   * `apple = Apple(...)` is sugar for `apple = Apple:create(...)`
      * `Apple:create()` calls `apple:init(...)`

## Inheritance and instantiation

**Classes are created** with `oo.ClassName([super])`, where `super` is
usually another class, but can also be an instance, which is useful for
creating polymorphic "views" on existing instances.

~~~{.lua}
local Fruit = oo.Fruit()
~~~

You can also create anonymous classes with `oo.class([super])`:

~~~{.lua}
local cls = oo.class()
~~~

**Instances are created** with `cls:create(...)` or simply `cls()`, which in
turn calls `cls:init(...)` which is the object constructor. While `cls` is
normally a class, it can also be an instance, which effectively enables
prototype-based inheritance.

~~~{.lua}
local obj = cls()
~~~

**The superclass** of a class or the class of an instance is accessible as
`self.super`.

~~~{.lua}
assert(obj.super == cls)
assert(cls.super == oo.Object)
~~~

**Inheritance is dynamic**: properties are looked up at runtime in
`self.super` and changing a property or method in the superclass reflects on
all subclasses and instances. This can be slow, but it saves space.

~~~{.lua}
cls.the_answer = 42
assert(obj.the_answer == 42)
~~~

You can detach the class/instance from its parent class by calling
`self:detach()`. This copies all inherited fields to the class/instance and
removes `self.super`.

~~~{.lua}
cls:detach()
obj:detach()
assert(obj.super == nil)
assert(cls.super == nil)
assert(cls.the_answer == 42)
assert(obj.the_answer == 42)
~~~

**Static inheritance** can be achieved by calling
`self:inherit(other[,override])` which copies over the properties of another
class or instance, effectively *monkey-patching* `self`, optionally
overriding properties with the same name. The fields `self.classname` and
`self.super` are always preserved though, even with the `override` flag.

~~~{.lua}
local other_cls = oo.class()
other_cls.the_answer = 13

obj:inherit(other_cls)
assert(obj.the_answer == 13) --obj continues to dynamically inherit cls.the_answer
                             --but statically inherited other_cls.the_answer

obj.the_answer = nil
assert(obj.the_answer == 42) --reverted to class default

cls:inherit(other_cls)
assert(cls.the_answer == 42) --no override

cls:inherit(other_cls, true)
assert(cls.the_answer == 13) --override
~~~

In fact, `self:detach()` is written as `self:inherit(self.super)` with the
minor detail of setting `self.classname = self.classname` and removing
`self.super`.

To further customize how the values are copied over for static inheritance,
override `self:properties()`.

**Virtual properties** are created by defining a getter and a setter. Once
you have defined `self:get_foo()` and `self:set_foo(value)` you can read and
write to `self.foo` and the getter and setter will be called to fulfill
the indexing. The setter is optional: without it, the property is read-only
and assigning it fails with an error.

~~~{.lua}
function cls:get_answer_to_life() return deep_thought:get_answer() end
function cls:set_answer_to_life(v) deep_thought:set_answer(v) end
obj = cls()
obj.answer_to_life = 42
assert(obj.answer_to_life == 42) --assuming deep_thought can store a number
~~~

## Virtual properties

**Stored properties** are virtual properties with a setter but no getter.
The values of those properties are stored in the table `self.state` upon
assignment of the property and read back upon indexing the property.
If the setter breaks, the value is not stored.

~~~{.lua}
function cls:set_answer_to_life(v) deep_thought:set_answer(v) end
obj = cls()
obj.answer_to_life = 42
assert(obj.answer_to_life == 42) --we return the stored the number
assert(obj.state.answer_to_life == 42) --which we stored here
~~~

Virtual and inherited properties are all read by calling
`self:getproperty(name)`. Virtual and real properties are written to with
`self:setproperty(name, value)`. You can override these methods for
*finer control* over the behavior of virtual and inherited properties.

Virtual properties can be *generated in bulk* given a _multikey_ getter and
a _multikey_ setter and a list of property names, by calling
`self:gen_properties(names, getter, setter)`. The setter and getter must be
methods of form:

  * `self:getter(k) -> v`
  * `self:setter(k, v)`

## Overriding hooks

Overriding hooks are sugar to make method overriding more easy and readable.

Instead of:

~~~{.lua}
function Apple:pick(arg)
	print('picking', arg)
	local ret = Apple.super.pick(self, arg)
	print('picked', ret)
	return ret
end
~~~

Write:

~~~{.lua}
function Apple:override_pick(inherited, arg, ...)
	print('picking', arg)
	local ret = inherited(self, arg, ...)
	print('picked', ret)
	return ret
end
~~~

Or even better:

~~~{.lua}
function Apple:before_pick(arg)
	print('picking', arg)
end

function Apple:after_pick(ret)
	print('picked', ret)
	return ret
end

~~~

By defining `self:before_<method>(...)` a new implementation for
`self.<method>` is created which calls the before hook (which receives all
method's arguments) and then calls the existing (inherited) implementation
with whatever the hook returns as arguments.

By defining `self:after_<method>(...)` a new implementation for
`self.<method>` is created which calls the existing (inherited)
implementation, after which it calls the hook with whatever the method
returns as arguments, and returns whatever the hook returns.

By defining `self:override_<method>(inherited, ...)` you can access
`self.super.<method>` as `inherited`.

~~~{.lua}
function cls:before_init(foo, bar)
  foo = foo or default_foo
  bar = bar or default_bar
  return foo, bar
end

function cls:after_init()
  --allocate resources
end

function cls:before_destroy()
  --destroy resources
end
~~~

If you don't know the name of the method you want to override until runtime,
use `cls:before(name, func)`, `cls:after(name, func)` and
`cls:override(name, func)` instead.

## Events

Events are for associating actions with functions. Events facts:

* events fire in the order in which they were added.
* extra args passed to `fire()` are passed to the event handlers.
* if the method `obj:<event>(args...)` is found, it is called first.
* returning a non-nil value from a handler interrupts the event handling
  call chain and the value is returned back by `fire()`.
* all uninterrupted events fire the `event` meta-event which inserts the
  event name on arg#1.
* events can be namespace-tagged with `'event.ns'`: namespsaces are useful
  for easy bulk event removal with `obj:off'.ns'`.
* multiple handlers can be added for the same event and/or namespace.
* handlers are stored as `self.observers[event] = {handler1, ...}`.

