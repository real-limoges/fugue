defmodule FugueWeb.Updates.Entry do
  @moduledoc """
  One site update in the `/feed.xml` RSS feed: a headline, a one-line
  description, the site-relative `url` it links to, and the day it shipped.
  The list itself lives in `FugueWeb.Updates`.
  """

  @enforce_keys [:title, :description, :url, :date]
  defstruct [:title, :description, :url, :date]

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t(),
          url: String.t(),
          date: Date.t()
        }
end
