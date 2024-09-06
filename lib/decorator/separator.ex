defmodule Decorator.Separator do
  defmacro __using__(_opts) do
    name =
      8
      |> :crypto.strong_rand_bytes()
      |> Base.encode16()
      |> String.downcase()
      |> then(&:"__decorator_separator_#{&1}__")

    quote do
      defp unquote(name)() do
        raise CompileError,
              "#{unquote(name)}/0 is internal decorator function to separate defoverridable/1, it should not be called"
      end
    end
  end
end
