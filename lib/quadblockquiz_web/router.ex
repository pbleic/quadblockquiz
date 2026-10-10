defmodule QuadblockquizWeb.Router do
  use QuadblockquizWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {QuadblockquizWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", QuadblockquizWeb do
    pipe_through :browser

    live "/", GameLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuadblockquizWeb do
  #   pipe_through :api
  # end
end
