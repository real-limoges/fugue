defmodule Fugue.BlogTest do
  use ExUnit.Case, async: true

  alias Fugue.Blog

  describe "list_posts/0" do
    test "returns posts sorted by date descending" do
      posts = Blog.list_posts()
      assert length(posts) > 0
      assert posts == Enum.sort_by(posts, & &1.date, {:desc, Date})
    end

    test "posts have required fields" do
      [post | _] = Blog.list_posts()
      assert post.slug
      assert post.title
      assert post.date
      assert is_binary(post.body)
      assert is_list(post.tags)
      assert is_binary(post.summary)
      assert is_boolean(post.draft)
    end

    test "excludes draft posts" do
      posts = Blog.list_posts()
      assert Enum.all?(posts, &(!&1.draft))
    end
  end

  describe "list_posts/1 with tag filter" do
    test "filters by tag" do
      posts = Blog.list_posts(tag: "meta")
      assert length(posts) > 0
      assert Enum.all?(posts, &("meta" in &1.tags))
    end

    test "returns empty list for unknown tag" do
      assert Blog.list_posts(tag: "nonexistent-tag-xyz") == []
    end
  end

  describe "get_post/1" do
    test "returns post by slug" do
      assert {:ok, post} = Blog.get_post("hello-world")
      assert post.title == "Hello World"
      assert post.slug == "hello-world"
    end

    test "returns error for unknown slug" do
      assert :error = Blog.get_post("does-not-exist")
    end
  end

  describe "all_tags/0" do
    test "returns sorted unique tags" do
      tags = Blog.all_tags()
      assert is_list(tags)
      assert tags == Enum.sort(tags)
      assert tags == Enum.uniq(tags)
    end
  end
end
