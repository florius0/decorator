# Elixir function decorators

[![Build Status](https://github.com/arjan/decorator/workflows/test/badge.svg)](https://github.com/arjan/decorator)
[![Module Version](https://img.shields.io/hexpm/v/decorator.svg)](https://hex.pm/packages/decorator)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/decorator/)
[![Total Download](https://img.shields.io/hexpm/dt/decorator.svg)](https://hex.pm/packages/decorator)
[![License](https://img.shields.io/hexpm/l/decorator.svg)](https://github.com/arjan/decorator/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/arjan/decorator.svg)](https://github.com/arjan/decorator/commits/master)

A function decorator is a "`@decorate`" annotation that is put just
before a function definition.  It can be used to add extra
functionality to Elixir functions. The runtime overhead of a function
decorator is zero, as it is executed on compile time.

Examples of function decorators include: loggers, instrumentation
(timing), precondition checks, et cetera.


## Some remarks in advance

Some people think function decorators are a bad idea, as they can
perform magic stuff on your functions (side effects!). Personally, I
think they are just another form of metaprogramming, one of Elixir's
selling points. But use decorators wisely, and always study the
decorator code itself, so you know what it is doing.

Decorators are always marked with the `@decorate` literal, so that
it's clear in the code that decorators are being used.


## Installation

Add `:decorator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:decorator, "~> 1.2"}
  ]
end
```

You can now define your function decorators.

## Usage

Function decorators are macros which you put just before defining a
function. It looks like this:

```elixir
defmodule MyModule do
  use PrintDecorator

  @decorate print()
  def square(a) do
    a * a
  end
end
```

Now whenever you call `MyModule.square()`, you'll see the message: `Function
called: square` in the console.

Defining the decorator is pretty easy. Create a module in which you
*use* the `Decorator.Define` module, passing in the decorator name and
arity, or more than one if you want.

The following declares the above `@print` decorator which prints a
message every time the decorated function is called:

```elixir
defmodule PrintDecorator do
  use Decorator.Define, [print: 0]

  def print(body, context) do
    quote do
      IO.puts("Function called: " <> Atom.to_string(unquote(context.name)))
      unquote(body)
    end
  end

end
```

The arguments to the decorator function (the `def print(...)`) are the
function's body (the abstract syntax tree (AST)), as well as a `context`
argument which holds information like the function's name, defining module,
arity and the arguments AST.


### Compile-time arguments

Decorators can have compile-time arguments passed into the decorator
macros.

For instance, you could let the print function only print when a
certain logging level has been set:

```elixir
@decorate print(:debug)
def foo() do
...
```

In this case, you specify the arity 1 for the decorator:

```elixir
defmodule PrintDecorator do
  use Decorator.Define, [print: 1]
```

And then your `print/3` decorator function gets the level passed in as
the first argument:

```elixir
def print(level, body, context) do
# ...
end
```

### Decorating all functions in a module

A shortcut to decorate all functions in a module is to use the `@decorate_all` attribute, as shown below. It is
important to note that the `@decorate_all` attribute only
affects the function clauses below its definition.

```elixir
defmodule MyApp.APIController
  use MyBackend.LoggerDecorator

  @decorate_all log_request()

  def index(_conn, params) do
    # ...
  end

  def detail(_conn, params) do
    # ...
  end
```

In this example, the `log_request()` decorator is applied to both
`index/2` and `detail/2`.


### Functions with multiple clauses

If you have a function with multiple clauses, and only decorate one
clause, you will notice that you get compiler warnings about unused
variables and other things. For functions with multiple clauses the
general advice is this: You should create an empty function head, and
call the decorator on that head, like this:

```elixir
defmodule DecoratorFunctionHead do
  use DecoratorFunctionHead.PrintDecorator

  @decorate print()
  def hello(first_name, last_name \\ nil)

  def hello(:world, _last_name) do
    :world
  end

  def hello(first_name, last_name) do
    "Hello #{first_name} #{last_name}"
  end
end
```


### Decorator context

Besides the function body AST, the decorator function also gets a
*context* argument passed in. This context holds information about the
function being decorated, namely its module, function name, arity, function
kind, and arguments as a list of AST nodes.

The print decorator can print its function name like this:

```elixir
def print(body, context) do
  Logger.debug("Function #{context.name}/#{context.arity} with kind #{context.kind} called in module #{context.module}!")
end
```

Even more advanced, you can use the function arguments in the
decorator.  To create an `is_authorized` decorator which performs some
checks on the Phoenix %Conn{} structure, you can create a decorator
function like this:

```elixir
def is_authorized(body, %{args: [conn, _params]}) do
  quote do
    if unquote(conn).assigns.user do
      unquote(body)
    else
      unquote(conn)
      |> send_resp(401, "unauthorized")
      |> halt()
    end
  end
end
```

### Simple reflection for all decorated functions
A "hidden" function `__decorated_functions__/0` is added to any module that decorates functions and returns a list of 
all decorated functions within that module. 

This can be useful for testing purposes since you don't have to assert the decorated behaviors of the decorated 
functions.  So long as your decorator function is well tested, you can just assert the expected decorators are present
for the given function.

The function returns a map with the function name and arguments as the key and a list of tuples with the decorator.
This permits multiple decorators to be asserted with a single function call so that adding new decorators will cause
the assertion to fail.

For example, given the following module:
```elixir
  defmodule NewModule do
    use Decorator.Define, [new_decorator: 1, another_decorator: 2]

    @decorate new_decorator("one")
    def func(%StructOne{} = msg) do
      msg
    end

    @decorate new_decorator("two")
    @decorate another_decorator("a", "b")
    @decorate new_decorator("b")
    def func(%StructTwo{c: 2} = _msg) do
      :ok
    end
  end
```

You can assert the decorated functions like so:
```elixir
  test "Module with decorated functions are returned by `__decorated_functions__()" do
    assert %{
             {:func, ["%StructOne{} = msg"]} => [
               {DecoratorTest.Fixture.NewDecorator, :new_decorator, ["one"]}
             ],
             {:func, ["%StructTwo{c: 2} = _msg"]} => [
               {DecoratorTest.Fixture.NewDecorator, :new_decorator, ["two"]},
               {DecoratorTest.Fixture.AnotherDecorator, :another_decorator, ["a", "b"]},
               {DecoratorTest.Fixture.NewDecorator, :new_decorator, ["b"]}
             ]
           } == NewModule.__decorated_functions__()
  end
```

Obviously, any changes to the parameters of the decorated function will cause the simple assertion to fail, but that's
intentional, as the decorator may be dependent on the parameters of the decorated function.

## Copyright and License

Copyright (c) 2016 Arjan Scherpenisse

This library is MIT licensed. See the
[LICENSE](https://github.com/arjan/decorator/blob/master/LICENSE) for details.
