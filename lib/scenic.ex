defmodule Scenic do
  @moduledoc """

  Scenic is an application framework written directly on the Elixir/Erlang/OTP stack.
  With it you can build client-side applications that operate identically across all
  supported operating systems, including MacOS, Ubuntu, Nerves/Linux, and more.

  ## Helpful Guides

    * [Scenic Overview](overview_general.html)
    * [Getting Started](getting_started.html)
    * [Structure of a Scene](scene_structure.html)
    * [Lifecycle of a Scene](scene_lifecycle.html)
    * [Overview of a ViewPort](overview_viewport.html)
    * [Overview of a Driver](overview_driver.html)
    * [Mix Tasks](mix_tasks.html)

  If you are new to scenic, then you should read the [Scenic Overview](overview_general.html),
  [Getting Started](getting_started.html), and [Mix Tasks](mix_tasks.html) guides first.

  ## Configure Scenic

  In order to start Scenic, you should first build a configuration for one or more
  ViewPorts. These configuration maps will be passed in to the main Scenic
  supervisor. These configurations should live in your app's config.exs file.

      use Mix.Config

      # Configure the main viewport for the Scenic application
      config :my_application, :viewport, %{
            name: :main_viewport,
            size: {700, 600},
            default_scene: {<%= @mod %>.Scene.First, nil},
            drivers: [
              %{
                module: Scenic.Driver.Glfw,
                name: :glfw,
                opts: [resizeable: false, title: "Example Application"],
              }
            ]
          }

  In the ViewPort configuration you can do things like set a name for the 
  ViewPort process, its size, the default scene and start one or more drivers.

  See the documentation for [ViewPort Configuration](Scenic.ViewPort.Config.html)
  to learn more about how to set the options on a viewport.

  Note that all the drivers are in seperate Hex packages as you should choose the
  correct one for your application. For example, the `Scenic.Driver.Glfw` driver draws
  your scenes into a window under MacOS and Ubuntu. It should work on other
  OS's as well, such as other flavors of Unix or Windows, but I haven't worked
  on or tested those yet.

  ## Supervise Scenic

  The Scenic module itself is a supervisor that manages all the machinery that
  makes the [Scenes](overview_scene.html), [ViewPorts](overview_viewport.html),
  and [Drivers](overview_driver.html) run.
  
  In order to run any Scenic application, you will need to start the Scenic
  supervisor in your supervision tree.

  Load a configuration for one or more ViewPorts, then add Scenic to your root supervisor.
  
      defmodule MyApplication do

        def start(_type, _args) do
          import Supervisor.Spec, warn: false

          # load the viewport configuration from config
          main_viewport_config = Application.get_env(:my_application :viewport)

          # start the application with the viewport
          children = [
            supervisor(Scenic, [viewports: [main_viewport_config]]),
          ]
          Supervisor.start_link(children, strategy: :one_for_one)
        end

      end

  Note that you can start the Scenic supervisor without any ViewPort
  Configurations. In that case, you are responsible for supervising
  the ViewPorts yourself. This is not recommended for devices
  as Scenic should know how to restart the main ViewPort in the event
  of an error.
  """

  use Supervisor

  @viewports :scenic_dyn_viewports

  # --------------------------------------------------------
  @doc false
  def child_spec(opts) do
    %{
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 500
    }
  end

  # --------------------------------------------------------
  @doc false
  def start_link(opts \\ [])
  def start_link({a, b}), do: start_link([{a, b}])

  def start_link(opts) when is_list(opts) do
    Supervisor.start_link(__MODULE__, opts, name: :scenic)
  end

  # --------------------------------------------------------
  @doc false
  def init(opts) do
    opts
    |> Keyword.get(:viewports, [])
    |> do_init
  end

  # --------------------------------------------------------
  # init with no default viewports
  defp do_init([]) do
    [
      {Scenic.ViewPort.Tables, nil},
      supervisor(Scenic.Cache.Supervisor, []),
      {DynamicSupervisor, name: @viewports, strategy: :one_for_one}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end

  # --------------------------------------------------------
  # init with default viewports
  defp do_init(viewports) do
    [
      {Scenic.ViewPort.Tables, nil},
      supervisor(Scenic.Cache.Supervisor, []),
      supervisor(Scenic.ViewPort.SupervisorTop, [viewports]),
      {DynamicSupervisor, name: @viewports, strategy: :one_for_one}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end
end
