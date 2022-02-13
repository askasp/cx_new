defmodule Mix.Tasks.Cx.Gen.Init do
  @shortdoc "Generates authentication logic for a resource"

  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen
  alias Mix.Cx.Gen.Injector

  @switches [web: :string, binary_id: :boolean, hashing_lib: :string, table: :string]

  @impl true
  def run(args, test_opts \\ []) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.auth can only be run inside an application directory")
    end

    ctx_app = Mix.Phoenix.context_app()
    base = Module.concat([Mix.Phoenix.context_base(ctx_app)])

    context = %{
      base_module: base,
      web_module: web_module(),
      context_app: ctx_app
    }

    if Keyword.get(test_opts, :validate_dependencies?, true) do
      Mix.Task.run("compile")
      validate_required_dependencies!()
    end

    binding = [
      context: context,
      web_app_name: web_app_name(context),
      endpoint_module: Module.concat([context.web_module, Endpoint])
    ]

    paths = generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding, paths)

    # |> inject_routes(paths, binding)
    # |> print_shell_instructions()
  end

  defp web_app_name(context) do
    context.web_module
    |> inspect()
    |> Phoenix.Naming.underscore()
  end

  defp web_module do
    base = Mix.Phoenix.base()

    cond do
      Mix.Phoenix.context_app() != Mix.Phoenix.otp_app() ->
        Module.concat([base])

      String.ends_with?(base, "Web") ->
        Module.concat([base])

      true ->
        Module.concat(["#{base}Web"])
    end
  end

  defp validate_required_dependencies! do
    if generated_with_no_html?() do
      raise_with_help("mix phx.gen.auth requires phoenix_html", :phx_generator_args)
    end
  end

  defp generated_with_no_html? do
    Mix.Project.config()
    |> Keyword.get(:deps, [])
    |> Enum.any?(fn
      {:phoenix_html, _} -> true
      {:phoenix_html, _, _} -> true
      _ -> false
    end)
    |> Kernel.not()
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp files_to_be_generated(%{context_app: context_app}) do
    web_prefix = Mix.Phoenix.web_path(context_app)

    [
      {:eex, "root.html.heex", Path.join([web_prefix, "templates", "layout", "root.html.heex"])},
      {:eex, "live.html.heex", Path.join([web_prefix, "templates", "layout", "live.html.heex"])},
      {:eex, "router.ex", Path.join([web_prefix, "router.ex"])},
      {:eex, "page_live.ex", Path.join([web_prefix, "live", "page", "page_live.ex"])},
      {:eex, "command_dispatcher.ex", Path.join(["lib/cx_scaffold", "command_dispatcher.ex"])},
      {:eex, "read_model_supervisor.ex", Path.join(["lib/cx_scaffold", "read_model_supervisor.ex"])}
    ]
  end

  defp copy_new_files(context, binding, paths) do
    files = files_to_be_generated(context)
    IO.inspect(paths)
    Mix.Phoenix.copy_from(paths, "priv/templates/cx.gen.init", binding, files)
    context
  end

  defp inject_routes(%{context_app: ctx_app} = context, paths, binding) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")

    paths
    |> Mix.Phoenix.eval_from("priv/templates/cx.gen.init/routes.ex", binding)
    |> inject_before_final_end(file_path)

    context
  end

  defp print_shell_instructions(context) do
    Mix.shell().info("""

    Please re-fetch your dependencies with the following command:

        mix deps.get
    """)

    Mix.shell().info("""

    Remember to update your repository by running migrations:

      $ mix ecto.migrate
    """)

    context
  end

  # The paths to look for template files for generators.
  #
  # Defaults to checking the current app's `priv` directory,
  # and falls back to phx_gen_auth's `priv` directory.
  defp generator_paths do
    [".", :cx_new, :phoenix]
    # IO.inspect "heisann"
    # ["../cx_new", :cx_new]
  end

  defp inject_before_final_end(content_to_inject, file_path) do
    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <- Injector.inject_before_final_end(file, content_to_inject) do
      print_injecting(file_path)
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)

        print_unable_to_read_file_error(
          file_path,
          """

          Please add the following to the end of your equivalent
          #{Path.relative_to_cwd(file_path)} module:

          #{indent_spaces(content_to_inject, 2)}
          """
        )
    end
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, file} -> {:ok, file}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp prepend_newline(string), do: "\n" <> string

  # This can be replaced with Context.pre_exisiting_test_fixtures?/1
  # in phoenix 1.6
  defp pre_exisiting_test_fixtures?(%Context{} = context) do
    context |> get_test_fixtures_file() |> File.exists?()
  end

  # This can be updated to use %Context{test_fixtures_file: _} in
  # Phoenix 1.6
  defp get_test_fixtures_file(%Context{name: context_name, context_app: ctx_app}) do
    basedir = Phoenix.Naming.underscore(context_name)
    test_fixtures_dir = Mix.Phoenix.context_app_path(ctx_app, "test/support/fixtures")
    Path.join([test_fixtures_dir, basedir <> "_fixtures.ex"])
  end

  defp indent_spaces(string, number_of_spaces) when is_binary(string) and is_integer(number_of_spaces) do
    indent = String.duplicate(" ", number_of_spaces)

    string
    |> String.split("\n")
    |> Enum.map(&(indent <> &1))
    |> Enum.join("\n")
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp get_ecto_adapter!(%Schema{repo: repo}) do
    if Code.ensure_loaded?(repo) do
      repo.__adapter__()
    else
      Mix.raise("Unable to find #{inspect(repo)}")
    end
  end

  defp print_injecting(file_path, suffix \\ []) do
    Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path), suffix])
  end

  defp print_unable_to_read_file_error(file_path, help_text) do
    Mix.shell().error(
      """

      Unable to read file #{Path.relative_to_cwd(file_path)}.

      #{help_text}
      """
      |> indent_spaces(2)
    )
  end

  @doc false
  def raise_with_help(msg) do
    raise_with_help(msg, :general)
  end

  defp raise_with_help(msg, :general) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth expects a context module name, followed by
    the schema module and its plural name (used as the schema
    table name).

    For example:

        mix phx.gen.auth Accounts User users

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Payments.User).
    """)
  end

  defp raise_with_help(msg, :phx_generator_args) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth must be installed into a Phoenix 1.5 app that
    contains ecto and html templates.

        mix phx.new my_app
        mix phx.new my_app --umbrella
        mix phx.new my_app --database mysql

    Apps generated with --no-ecto and --no-html are not supported.
    """)
  end

  defp raise_with_help(msg, :hashing_lib) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth supports the following values for --hashing-lib

      * bcrypt
      * pbkdf2
      * argon2

    Visit https://github.com/riverrun/comeonin for more information
    on choosing a library.
    """)
  end

  defp test_case_options(Ecto.Adapters.Postgres), do: ", async: true"
  defp test_case_options(adapter) when is_atom(adapter), do: ""
end
