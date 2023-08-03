defmodule Mix.Tasks.CreateData do
  @moduledoc "Go through Elixir your modules and pull out function docs into a jsonl file"

  use Mix.Task
  @file_name "data.jsonl"

  @impl Mix.Task
  def run(_args) do
    File.rm(@file_name)

    get_all_modules()
    |> Enum.each(fn module ->
      process_module(module)
    end)
  end

  def get_all_modules() do
    [:mix, :eex, :elixir, :ex_unit, :iex, :logger]
    |> Enum.map(fn app ->
      case :application.get_key(app, :modules) do
        {:ok, modules} -> modules
        _ -> []
      end
    end)
    |> List.flatten()
  end

  defp process_module(module_name) when is_atom(module_name) do
    case module_name |> Code.fetch_docs() do
      {:docs_v1, _, _, _content_type, _docstring, _module_metadata, functions} ->
        outputs =
          functions
          |> Enum.map(fn f -> function_data(f, module_name) end)
          |> Enum.reject(fn
            {:error, _} -> true
            _ -> false
          end)

        Enum.each(outputs, fn {:ok, data} ->
          json = Jason.encode!(data)
          IO.puts("Writing #{module_name}")
          File.write!(@file_name, json <> "\n", [:append, {:encoding, :utf8}])
        end)

      {:error, _} ->
        IO.puts("Error on #{module_name}")
    end
  end

  defp function_data(
         {{:function, _name, _arity}, _anno, signature, %{"en" => doc_content}, _metadata},
         module_name
       ) do
    {:ok, %{"prompt" => "#{module_name}.#{signature}: #{doc_content}", "completion" => ""}}
  end

  defp function_data(
         {{type, name, _arity}, _anno, _signature, _doc_content, _metadata},
         _module_name
       ) do
    {:error, "We don't care about #{type} #{name} yet"}
  end
end
