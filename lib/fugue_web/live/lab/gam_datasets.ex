defmodule FugueWeb.LabLive.GamDatasets do
  @moduledoc """
  Static dataset definitions for `/lab/gam` -- four scatter problems each
  paired with prose blurbs and per-layer captions. Lives in its own module
  so the view stays focused on UI logic.
  """

  @datasets [
    %{
      id: "house_price",
      label: "Sale price vs floor area",
      title: "Floor area and sale price",
      blurb:
        "Sale prices against floor area, on a market that includes 700-square-foot starters and 4,500-square-foot custom builds. The mean rises with size, and so does the spread -- a 4,000-sqft house has a lot more room to be cheap or expensive than a 700-sqft one does. A straight line gets the slope and loses everything else.",
      layers: [
        %{id: "linear", label: "-- Linear", accent: :white_dash},
        %{id: "gam", label: "⌇ GAM (Normal)", accent: :gray},
        %{id: "gamlss", label: "◈ GAMLSS (Gamma)", accent: :primary}
      ],
      captions: [
        %{
          glyph: "--",
          accent: :white_dim,
          text:
            "A line averages a market that scatters very differently at each scale -- off at the small end, off at the large end, indifferent about why."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Normal GAM bends to the actual mean, but holds spread constant across the whole market. The gray band is the same width at 800 sqft as at 4,000 -- wrong in both directions."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Gamma GAMLSS lets the spread ride along with the mean. The orange band fans out at the high end where prices genuinely vary, and tightens at the low end where they don't."
        }
      ]
    },
    %{
      id: "bay_bridge",
      label: "Bay Bridge tolls by hour",
      title: "Bay Bridge tolls by hour of day",
      blurb:
        "Cars per minute through the Bay Bridge toll plaza, four days stacked. Two peaks -- commuting in around 8, commuting home around 5:30 -- and a quiet midday. The peaks scatter way harder than the lulls: a Tuesday at 8am and a Saturday at 8am are different populations. Poisson and Negative Binomial disagree about how to admit that.",
      layers: [
        %{id: "linear", label: "-- Linear (Poisson)", accent: :white_dash},
        %{id: "gam", label: "⌇ Poisson GAM", accent: :gray},
        %{id: "gamlss", label: "◈ NegBin GAMLSS", accent: :primary}
      ],
      captions: [
        %{
          glyph: "--",
          accent: :white_dim,
          text:
            "A log-linear fit through counts; it can't bend around two peaks, just slope between them."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Poisson GAM finds the bimodal shape, but Poisson forces variance equal to the mean. Its band is too tight at the peaks, where the day-to-day variation is actually much bigger."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Negative Binomial lets variance grow faster than the mean. The orange band widens at the peaks and the model stops surprising itself."
        }
      ]
    },
    %{
      id: "pizza",
      label: "Pizza delivery vs distance",
      title: "Pizza delivery time and distance",
      blurb:
        "Minutes from order to door, against miles of driving. Most deliveries follow a clean curve -- fixed cooking time plus a few minutes per mile. The outliers are real: a driver got lost; the kitchen forgot; the route was empty at 11pm. Both directions, sometimes way out. (Pizza here is famously, persistently bad -- the only thing more reliable than the curve is the disappointment at the end of it.)",
      layers: [
        %{id: "linear", label: "-- Linear", accent: :white_dash},
        %{id: "gam", label: "⌇ Normal GAM", accent: :gray},
        %{id: "gamlss", label: "◈ Student-t GAMLSS", accent: :primary}
      ],
      captions: [
        %{
          glyph: "--",
          accent: :white_dim,
          text:
            "A straight line gets dragged off-center by the disaster runs and misses the slight nonlinearity at long distances."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Normal GAM bends to the curve, but five wild deliveries persuade it to widen the band globally. Three-mile orders get the same uncertainty as the seven-mile ones."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Student-t expects the occasional disaster and treats it as a tail event. The orange band stays narrow where most deliveries actually behave."
        }
      ]
    },
    %{
      id: "shot_success",
      label: "Shot success vs distance",
      title: "Shooting accuracy and distance from the basket",
      blurb:
        "Shot success rate against distance from the rim. Layups go in almost every time; half-court heaves go in almost never. The response is a proportion, pinned to (0, 1) by definition. A Normal band can't see the walls and walks straight through them. Beta with a logit link knows where they are. (I have a Warriors season pass. Steph Curry, statistically, is not supposed to be making 35-footers. He keeps making 35-footers.)",
      layers: [
        %{id: "linear", label: "-- Linear (Normal)", accent: :white_dash},
        %{id: "gam", label: "⌇ Normal GAM", accent: :gray},
        %{id: "gamlss", label: "◈ Beta GAMLSS", accent: :primary}
      ],
      captions: [
        %{
          glyph: "--",
          accent: :white_dim,
          text:
            "Linear regression doesn't know the response is bounded; it predicts negative shooting percentages and shrugs."
        },
        %{
          glyph: "⌇",
          accent: :gray,
          text:
            "Normal GAM bends to the shape, but its band can still punch through 0 or 1. Normal doesn't have edges built in."
        },
        %{
          glyph: "◈",
          accent: :primary,
          text:
            "Beta on a logit link respects the bounds. The orange band squeezes asymmetrically near 0 and 1 -- when you're pinned against a wall, uncertainty stops being symmetric."
        }
      ]
    }
  ]

  @ids Enum.map(@datasets, & &1.id)
  @by_id Map.new(@datasets, &{&1.id, &1})

  def all, do: @datasets

  def ids, do: @ids

  def fetch(id), do: Map.fetch(@by_id, id)
end
