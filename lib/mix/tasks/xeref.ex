defmodule Mix.Tasks.Xeref do
  use Mix.Task

  def run(_args) do
    Mix.Task.run(:loadpaths)
    xref_checks = [:undefined_function_calls, :undefined_functions,
    :locals_not_used, 
    :deprecated_function_calls, :deprecated_functions]

    {:ok, pid} = :xref.start(xref_mode: :functions)
    :xref.set_library_path(pid, :code.get_path)
    :xref.set_default(pid, [warnings: true, verbose: true])
    :xref.add_directory(pid, String.to_charlist(Mix.Project.compile_path))
    result = Enum.map(xref_checks, fn check -> :xref.analyze(pid, check) end)
    IO.inspect(result)
  end
end
