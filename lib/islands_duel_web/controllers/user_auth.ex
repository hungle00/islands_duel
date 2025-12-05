defmodule IslandsDuelWeb.UserAuth do
  import Plug.Conn
  # (for `put_flash` and `redirect`)
  import Phoenix.Controller

  use Phoenix.VerifiedRoutes,
    endpoint: IslandsDuelWeb.Endpoint,
    router: IslandsDuelWeb.Router,
    statics: IslandsDuelWeb.static_paths()

  def login_user(conn, user) do
    socket_id = :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_session(:current_user, user)
    |> put_session(:live_socket_id, "users_sockets:#{socket_id}")
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  # This function renews the session ID and erases the whole session to avoid
  # fixation attacks. If there is any data in the session you may want to
  # preserve after login/logout, you must explicitly fetch the session data
  # before clearing and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def logout_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      IslandsDuelWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    current_user = get_session(conn, :current_user)
    assign(conn, :current_user, current_user)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must login to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/session/new")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET", request_path: request_path} = conn) do
    put_session(conn, :user_return_to, request_path)
  end

  defp signed_in_path(_conn), do: ~p"/"
end
