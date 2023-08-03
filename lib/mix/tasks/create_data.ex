defmodule Mix.Tasks.CreateData do
  @moduledoc "Go through Elixir your modules and pull out function docs into a jsonl file"

  use Mix.Task
  @file_name "data.jsonl"

  @impl Mix.Task
  def run(_args) do
    File.rm(@file_name)

    [:mix, :eex, :elixir, :ex_unit, :iex, :logger]
    |> get_all_modules()
    |> Enum.map(&process_module/1)
    |> List.flatten()
    |> Enum.each(&write_jsonl/1)

    # |> process_module()
    # |> write_jsonl()
    # end)
  end

  def get_all_modules(modules) do
    modules
    |> Enum.map(fn app ->
      case :application.get_key(app, :modules) do
        {:ok, modules} -> modules
        _ -> []
      end
    end)
    |> List.flatten()
  end

  defp process_module(module_name) do
    case Code.fetch_docs(module_name) do
      {:docs_v1, _, _, _content_type, docstring, _module_metadata, functions} ->
        data =
          Enum.map(functions, fn f -> function_data(f, module_name) end) ++
            module_data(%{doc_content: docstring, module_name: module_name})

        Enum.filter(data, fn x -> x != nil end)

      {:error, _} ->
        # IO.puts("Error on #{module_name}")

        []
    end
  end

  defp module_data(%{doc_content: %{"en" => doc_content}, module_name: module_name}) do
    doc_content
    |> String.split(~r/\n##/)
    |> Enum.map(fn x -> String.trim(x) end)
    |> Enum.map(fn content ->
      {:ok, %{signature: module_name, doc_content: content, module_name: module_name}}
    end)
  end

  defp module_data(%{doc_content: _other}) do
    []
  end

  defp function_data(
         {{:function, _name, _arity}, _anno, signature, %{"en" => doc_content}, _metadata},
         module_name
       ) do
    {:ok, %{signature: signature, doc_content: doc_content, module_name: module_name}}
  end

  defp function_data(_, _) do
    nil
  end

  def write_jsonl(outputs) when is_list(outputs) do
    Enum.each(outputs, &write_jsonl/1)
  end

  def write_jsonl({:ok, data}) do
    json = Jason.encode!(generate_prompt(data)) <> "\n"
    File.write!(@file_name, json, [:append, {:encoding, :utf8}])
  end

  def generate_prompt(%{signature: signature, doc_content: doc_content, module_name: module_name}) do
    %{"prompt" => "#{module_name}.#{signature}: #{doc_content}", "completion" => ""}
  end
end
