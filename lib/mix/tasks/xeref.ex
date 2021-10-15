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
    result = Enum.map(xref_checks, fn check -> 
      {:ok, r} = :xref.analyze(pid, check)
      {check, r}
     end)
    textResult = format_errors(result)
    IO.puts(List.to_string(textResult))
  end
  
  # the following code is from rebar_priv_xref which was erlang
  defp format_errors(xrefResults) do
    :lists.flatten(display_results(xrefResults))
  end


  defp display_results(xrefResults) do
    :lists.map(&display_xref_results_for_type/1, xrefResults)
  end

  defp display_xref_results_for_type({type, xrefResults}) do
    :lists.map(display_xref_result_fun(type), xrefResults)
  end


  defp display_xref_result_fun(type) do
    fn xrefResult ->
      {source, sMFA, tMFA} = case(xrefResult) do
        {mFASource, mFATarget} ->
          {format_mfa_source(mFASource), format_mfa(mFASource), format_mfa(mFATarget)}
        mFATarget ->
          {format_mfa_source(mFATarget), format_mfa(mFATarget), :undefined}
      end
      case(type) do
        :undefined_function_calls ->
          :io_lib.format('~tsWarning: ~ts calls undefined function ~ts (Xref)\n', [source, sMFA, tMFA])
        :undefined_functions ->
          :io_lib.format('~tsWarning: ~ts is undefined function (Xref)\n', [source, sMFA])
        :locals_not_used ->
          :io_lib.format('~tsWarning: ~ts is unused local function (Xref)\n', [source, sMFA])
        :exports_not_used ->
          :io_lib.format('~tsWarning: ~ts is unused export (Xref)\n', [source, sMFA])
        :deprecated_function_calls ->
          :io_lib.format('~tsWarning: ~ts calls deprecated function ~ts (Xref)\n', [source, sMFA, tMFA])
        :deprecated_functions ->
          :io_lib.format('~tsWarning: ~ts is deprecated function (Xref)\n', [source, sMFA])
        other ->
          :io_lib.format('~tsWarning: ~ts - ~ts xref check: ~ts (Xref)\n', [source, sMFA, tMFA, other])
      end
    end
  end


  defp format_mfa({m, f, a}) do
    :io_lib.format('~ts:~ts/~w', [m, f, a])
  end


  defp format_mfa_source(mFA) do
    case(find_mfa_source(mFA)) do
      {:module_not_found, :function_not_found} ->
        []
      {source, :function_not_found} ->
        :io_lib.format('~ts: ', [source])
      {source, line} ->
        :io_lib.format('~ts:~w: ', [source, line])
    end
  end


  defp safe_element(n, tuple) do
    try do
      :erlang.element(n, tuple)
    catch
      :error, :badarg ->
        :undefined
    end
  end


  defp find_mfa_source({m, f, a}) do
    case(:code.get_object_code(m)) do
      :error ->
        {:module_not_found, :function_not_found}
      {^m, bin, _} ->
        find_function_source(m, f, a, bin)
    end
  end


  defp find_function_source(m, f, a, bin) do
    chunksLookup = :beam_lib.chunks(bin, [:abstract_code])
    {:ok, {^m, [abstract_code: abstractCodeLookup]}} = chunksLookup
    case(abstractCodeLookup) do
      :no_abstract_code ->
        {:module_not_found, :function_not_found}
      {:raw_abstract_v1, abstractCode} ->
        find_function_source_in_abstract_code(f, a, abstractCode)
    end
  end


  defp find_function_source_in_abstract_code(f, a, abstractCode) do
    [{:attribute, _, :file, {source, _}} | _] = abstractCode
    var_fn = for(e <- abstractCode, safe_element(1, e) == :function, safe_element(3, e) == f, safe_element(4, e) == a, into: [], do: e)
    case(var_fn) do
      [{:function, line, ^f, _, _}] ->
        {source, line}
      [] ->
        {source, :function_not_found}
    end
  end

end
