defmodule Fugue.Amigos do
  @moduledoc """
  The 23 layers of Arrested Development S2E3, "¡Amigos!", for the `/amigos`
  page.

  Each layer is one group of gags that stack through the episode: what
  stacks (`summary`), the scroll beats it appears on (`beats`, 1 to
  `last_beat/0`), and what it connects to in other episodes
  (`connections`). The page reveals layers beat by beat and ends on a
  counter that is one short, the way the episode's Narrator counts four
  people in a group of five.

  The layer it leaves out is Ann's. She is on the page from beat 8 like
  every other layer, but `counted: false`, so `counted_count/0` is one less
  than the number of layers. The counter must come from that function and
  never from a literal.

  Transcribed from `docs/reference/amigos-denser-page-design.md`, which
  records the sources behind each row.
  """

  @layers [
    %{
      id: :gobs_friend,
      name: "Gob's friend",
      summary:
        "Michael jokes Gob has no friends. Gob hires Ice and introduces him as a friend; " <>
          "Lindsay points out he has none. It resolves with Michael paying Gene and Ice " <>
          "to be Gob's friend.",
      beats: [1, 2],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S1E19 "Best Man for the Gob"),
          note: "Hot Cops posing as friends"
        }
      ]
    },
    %{
      id: :ice_off_duty,
      name: "Ice off duty",
      summary:
        "Ice is a bounty hunter, but lists party planning as his real passion and lives " <>
          "near Legoland; the phone book carries two ads for him, one for each job. An ice " <>
          "machine is prominent in the episode that introduces him. Michael promises " <>
          "Legoland tickets to George Michael.",
      beats: [2],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S1E13 "Beef Consommé"),
          note: ~s(a dictionary page lists "hielo")
        },
        %{direction: :internal, target: nil, note: "the two phone-book ads"},
        %{
          direction: :foreshadowing,
          target: "Season 3",
          note: "a Legoland line (episode not confirmed)"
        }
      ]
    },
    %{
      id: :surveillance,
      name: "Surveillance by proxy",
      summary:
        "Lucille's private eye, Gene, locates George Sr. in Mexico, and Lucille also pays " <>
          "him to track Gob. Gob, thinking Michael is fleeing the business, hires the bounty " <>
          "hunter Ice to follow him; in Mexico, Michael hires the same Ice to find George Sr. " <>
          "Gob tackles Michael, Gene tackles Gob, Ice tackles Michael.",
      beats: [3],
      counted: true,
      connections: [
        %{direction: :internal, target: nil, note: "each pursuer is pursued by the next"}
      ]
    },
    %{
      id: :radio,
      name: "Radio signals",
      summary:
        "Ice and Gob signal each other over crackling radios while standing in the same " <>
          "room at Buster's Army going-away party.",
      beats: [3],
      counted: true,
      connections: [%{direction: :internal, target: nil, note: "the surveillance chain"}]
    },
    %{
      id: :silent_film,
      name: "Silent film",
      summary:
        "A fake Mexican silent melodrama explains why the chicken dance is offensive there; " <>
          "a pistol goes off and someone in the background falls. Bateman, Arnett and Hale " <>
          "play the angry Mexican, the dancer and the shot pianist.",
      beats: [4, 9, 14],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S1E15 "Staff Infection"),
          note: "the first chicken dance since"
        },
        %{direction: :internal, target: nil, note: "the hidden cast cameo"}
      ]
    },
    %{
      id: :tobias_blue,
      name: "Tobias blue",
      summary:
        "Blue Man Group makeup, counting down to 8:01 each night; \"blue myself\" to be " <>
          "relaxed for dinner. Blue handprints and a smear in the model home. Pinned at the " <>
          "end of the blueprint chain, he asks who wants to go to the hospital, then lands there.",
      beats: [5, 10],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S2E1 "The One Where Michael Leaves"),
          note: ~s("blue myself" first used)
        },
        %{
          direction: :callback,
          target: ~s(S2E2 "The One Where They Build a House"),
          note: "he is blue there too"
        }
      ]
    },
    %{
      id: :real_world_refs,
      name: "Real-world references",
      summary:
        "Lucille tells Buster to videotape \"the human pyramid\" and point to his " <>
          "\"Charlie Browns\" (an Abu Ghraib reference); she gives Annyong money to " <>
          "\"go see a Star War.\"",
      beats: [6],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S2E2 "The One Where They Build a House"),
          note: "Charlie Browns first used"
        },
        %{direction: :foreshadowing, target: ~s(S2E4 "Good Grief"), note: "the Peanuts gags"},
        %{direction: :foreshadowing, target: ~s(S2E11 "Out on a Limb"), note: ~s("Linus")}
      ]
    },
    %{
      id: :borrowed_misunderstandings,
      name: "Borrowed misunderstandings",
      summary:
        "Michael's remark about putting people in the trunk gets a look from Lupe; " <>
          "Mexicans line up to climb the stair car and leap the border wall.",
      beats: [7],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S1E6 "Charity Drive"),
          note: "the murder misunderstanding"
        },
        %{
          direction: :callback,
          target: ~s(S1E5 "Visiting Ours"),
          note: "the stair car over the prison fence"
        }
      ]
    },
    %{
      id: :crossed_conversations,
      name: "Crossed conversations",
      summary:
        "Maeby and Michael think they are discussing a shared problem; she means her mother " <>
          "and Ice, he means George Michael and Ann. Maeby calls her mother's crush on Ice " <>
          "\"not a race thing\"; Michael hears a race home and later says \"Yeah, we won.\" " <>
          "The Narrator notes they were never talking about the same person.",
      beats: [8],
      counted: true,
      connections: [%{direction: :internal, target: nil, note: ~s(a "Who's on first?" structure)}]
    },
    %{
      id: :hog,
      name: "Who's on that hog",
      summary:
        "Lindsay thinks Ice is following her; he is tailing Michael. She says to look at " <>
          "who's on that hog in the rearview, and Michael, stuck on \"Ann-hog,\" shouts " <>
          "\"George Michael!\"",
      beats: [8],
      counted: true,
      connections: [
        %{direction: :internal, target: nil, note: "the Ann-hog nickname, planted earlier"}
      ]
    },
    %{
      id: :offices_props,
      name: "Offices and props",
      summary:
        "Michael works in a supply closet with Mr. Bananagrabber Christmas cards. Gob swapped " <>
          "his desk for a pool table, now covered in desk games. A Cornballer box and mix sit " <>
          "in the office, and a Cloudmir vodka ad hangs on a wall in Mexico.",
      beats: [9],
      counted: true,
      connections: [
        %{direction: :internal, target: nil, note: "the banana stand and Cornballer running gags"}
      ]
    },
    %{
      id: :blueprint,
      name: "Blueprint chain",
      summary:
        "Starla prints on photo paper and blueprint paper. Michael takes a blueprint-style " <>
          "picture of George Sr. to Mexico; a local asks when to start building. Michael hands " <>
          "the picture to Ice, who tracks down Tobias in blue makeup and tackles him.",
      beats: [10],
      counted: true,
      connections: [%{direction: :internal, target: nil, note: "office supplies, then the blue"}]
    },
    %{
      id: :buster_mexico,
      name: "Buster's fake Mexico",
      summary:
        "Buster hides in Michael's trunk to dodge the Army and gets out at Lupe's house, " <>
          "believing it is Mexico (a cartographer fooled by \"the Mexican sun\"). He finds " <>
          "possessions Lucille gave away, including his old hand chair, which prompts him to " <>
          "say he never thought he'd miss a hand so much. He rides a work truck back to his " <>
          "own home and doesn't recognize it from the servants' entrance. Sitting on a bus " <>
          "bench, he covers an Army Officers ad so it reads \"Arm Off.\"",
      beats: [11],
      counted: true,
      connections: [
        %{
          direction: :foreshadowing,
          target: ~s(S2E11 "Out on a Limb"),
          note: "the hand loss, set up by the hand chair and the Arm Off bench"
        }
      ]
    },
    %{
      id: :planted_foreshadowing,
      name: "Planted foreshadowing",
      summary:
        "Ice mistakes Tobias for George Sr.; a blue picture of George Sr. hangs in the " <>
          "background; Annyong wears a mole shirt.",
      beats: [12],
      counted: true,
      connections: [
        %{
          direction: :foreshadowing,
          target: ~s("Scandalmakers"),
          note: "the show in which Tobias plays his father-in-law (episode not confirmed)"
        },
        %{
          direction: :foreshadowing,
          target: ~s(S2E18 "Righteous Brothers"),
          note: "the blue picture; George Sr. joins the Blue Man Group"
        },
        %{
          direction: :foreshadowing,
          target: "Later",
          note: "Annyong revealed as a mole (episode not confirmed)"
        }
      ]
    },
    %{
      id: :oscar,
      name: "Oscar",
      summary:
        "Lucille insists she's not having an affair with Buster's \"uncle,\" and dramatic " <>
          "music plays. Buster catches Lucille and Oscar in his reclaimed hand chair.",
      beats: [13],
      counted: true,
      connections: [
        %{
          direction: :foreshadowing,
          target: "Later",
          note: "Oscar revealed as Buster's father (episode not confirmed)"
        }
      ]
    },
    %{
      id: :spanish,
      name: "Spanish mistranslations",
      summary:
        "A silent-film title card is translated in English, the first of the episode's two " <>
          "purposeful mistranslations by one reviewer's count; the Cloudmir sign in Mexico is " <>
          "in broken Spanish; a Cornballer commercial is falsely redubbed in Spanish.",
      beats: [14],
      counted: true,
      connections: [%{direction: :internal, target: nil, note: "the episode's Mexico setting"}]
    },
    %{
      id: :friends_titles,
      name: "Friends titles",
      summary:
        "The third straight episode title to nod to the sitcom Friends: \"amigos\" is " <>
          "Spanish for \"friends,\" and the plot is Gob's search for a friend and Buster " <>
          "making friends with Lupe's family.",
      beats: [15],
      counted: true,
      connections: [
        %{direction: :callback, target: "S2E1 and S2E2", note: "the first two season 2 titles"}
      ]
    },
    %{
      id: :tracy,
      name: "Tracy",
      summary: "Tobias sarcastically tells Michael he forgot that Michael's wife is dead.",
      beats: [18],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: "Earlier",
          note: "the Bluths' insensitivity to Tracy's death (episode not confirmed)"
        }
      ]
    },
    %{
      id: :circumvent,
      name: ~s("Circumvent"),
      summary: ~s(Gob's first mispronunciation of the word, ending in "the ol' reach-around."),
      beats: [17],
      counted: true,
      connections: [
        %{
          direction: :foreshadowing,
          target: "Later",
          note: "a running gag that spreads to other words (episode not confirmed)"
        }
      ]
    },
    %{
      id: :posters_banners,
      name: "Posters and banners",
      summary:
        "A \"Never Give Up\" poster falls and Gob says to leave it where it is. He also knocks " <>
          "down his \"Don't Be Afraid to Make a Mistake\" poster, which answers his denial of " <>
          "making mistakes in S2E1, and shrugs that he won't beat himself up over it. The " <>
          "\"You're killing me, Buster\" banner, hung for Buster's Army going-away party, is " <>
          "the first of the suggestive banners.",
      beats: [19],
      counted: true,
      connections: [
        %{
          direction: :callback,
          target: ~s(S2E1 "The One Where Michael Leaves"),
          note: "his denial of making mistakes"
        },
        %{direction: :foreshadowing, target: ~s(S2E12 "Hand to God"), note: "the banner returns"}
      ]
    },
    %{
      id: :george_sr,
      name: "George Sr.",
      summary:
        "One brief non-speaking appearance, his smallest role to date, in the episode about " <>
          "finding him. His funeral is underway in a nearby church while they search.",
      beats: [16],
      counted: true,
      connections: [
        %{
          direction: :foreshadowing,
          target: ~s(S2E4 "Good Grief"),
          note: "reveals the funeral is for a death he faked"
        }
      ]
    },
    %{
      id: :gene,
      name: "Gene Parmesan",
      summary:
        "Lucille's private eye keeps turning up in paper-thin disguises, lifting the mask " <>
          "for a Lucille squeal. In Mexico a bearded Gene peels a fake mustache off over his " <>
          "real one. Lucille calls him the best; the Narrator says he was far from it, and he " <>
          "never caught George Sr. cheating.",
      beats: [20],
      counted: true,
      connections: [
        %{
          direction: :foreshadowing,
          target: ~s(S2E6 "Afternoon Delight"),
          note: ~s(his "Come on!", said after counting his money, recurs)
        },
        %{direction: :internal, target: nil, note: "his first appearance"}
      ]
    },
    %{
      id: :ann,
      name: "Ann",
      summary:
        "Michael can't place her (\"Her?\"), calls her \"Ann-hog,\" \"Plant\" and \"some " <>
          "girl,\" drives home without her and still doesn't recognize her. After Michael says " <>
          "it's like he's being forgotten, the show cuts to Ann stranded in Mexico. The " <>
          "Narrator says there were only four people in the group; there were five.",
      beats: [8],
      counted: false,
      connections: [
        %{
          direction: :internal,
          target: nil,
          note:
            ~s(the long-running gag at Ann's expense; the episode ends on "I don't like her" ) <>
              ~s(under a "Keep An Open Mind" poster)
        }
      ]
    }
  ]

  @doc "Every layer, in the order the episode's research table lists them."
  def layers, do: @layers

  @doc "The layer with the given id. Raises if there is none."
  def layer!(id),
    do: Enum.find(@layers, &(&1.id == id)) || raise(ArgumentError, "no layer #{inspect(id)}")

  @doc "The last beat that adds a layer. The ending comes one beat after it."
  def last_beat, do: @layers |> Enum.flat_map(& &1.beats) |> Enum.max()

  @doc """
  The beat a margin starts drawing arrows on: callbacks with the first layer
  that has one, foreshadowing with the first of the forward-pointing notes.
  """
  def arrows_from(:callback), do: first_beat(layer!(:silent_film))
  def arrows_from(:foreshadowing), do: first_beat(layer!(:buster_mexico))

  @doc "The first beat a layer appears on."
  def first_beat(layer), do: Enum.min(layer.beats)

  @doc "Every layer that is on the page by the given beat."
  def revealed_by(beat), do: Enum.filter(@layers, &(first_beat(&1) <= beat))

  @doc "A layer's connections in one direction: `:callback`, `:foreshadowing` or `:internal`."
  def connections(layer, direction),
    do: Enum.filter(layer.connections, &(&1.direction == direction))

  @doc """
  How many layers the ending's counter admits to: every layer except the
  uncounted one. This is the only source of the counter's number.
  """
  def counted_count, do: Enum.count(@layers, & &1.counted)
end
