defmodule ExYarnTest do
  use ExUnit.Case, async: true
  doctest ExYarn

  describe "parse files without merge conflicts" do
    no_conflict_tests = [
      {~s(foo:\n  bar\n), %{"foo" => "bar"}},
      {~s(foo "bar"), %{"foo" => "bar"}},
      {~s("foo" "bar"), %{"foo" => "bar"}},
      {~s(foo:\n  bar "bar"), %{"foo" => %{"bar" => "bar"}}},
      {~s(foo:\n  bar:\n  foo "bar"), %{"foo" => %{"bar" => %{}, "foo" => "bar"}}},
      {~s(foo:\n  bar:\n    foo "bar"), %{"foo" => %{"bar" => %{"foo" => "bar"}}}},
      {~s(foo:\r\n  bar:\r\n    foo "bar"), %{"foo" => %{"bar" => %{"foo" => "bar"}}}},
      {~s(foo:\n  bar:\n    yes no\nbar:\n  yes no),
       %{"foo" => %{"bar" => %{"yes" => "no"}}, "bar" => %{"yes" => "no"}}},
      {~s(foo:\r\n  bar:\r\n    yes no\r\nbar:\r\n  yes no),
       %{"foo" => %{"bar" => %{"yes" => "no"}}, "bar" => %{"yes" => "no"}}}
    ]

    Enum.each(no_conflict_tests, fn {input, result} ->
      @input input
      @result result

      test "#{input}" do
        {:ok, :success, result} = ExYarn.parse(@input)
        assert @result == result
      end
    end)
  end

  describe "parse merge conflicts" do
    test "parse single merge conflict" do
      input = """
      a:
        no "yes"

      <<<<<<< HEAD
      b:
        foo "bar"
      =======
      c:
        bar "foo"
      >>>>>>> branch-a

      d:
        yes "no"
      """

      expected_result = %{
        "a" => %{"no" => "yes"},
        "b" => %{"foo" => "bar"},
        "c" => %{"bar" => "foo"},
        "d" => %{"yes" => "no"}
      }

      {:ok, type, result} = ExYarn.parse(input)
      assert :merge == type
      assert expected_result == result
    end

    test "parse single merge conflict with CRLF" do
      input =
        ~s(a:\r\n  no "yes"\r\n\r\n<<<<<<< HEAD\r\nb:\r\n  foo "bar") <>
          ~s(\r\n=======\r\nc:\r\n  bar "foo"\r\n>>>>>>> branch-a) <>
          ~s(\r\n\r\nd:\r\n  yes "no"\r\n)

      expected_result = %{
        "a" => %{"no" => "yes"},
        "b" => %{"foo" => "bar"},
        "c" => %{"bar" => "foo"},
        "d" => %{"yes" => "no"}
      }

      {:ok, type, result} = ExYarn.parse(input)
      assert :merge == type
      assert expected_result == result
    end

    test "parse multiple merge conflicts" do
      input = """
      a:
        no "yes"

      <<<<<<< HEAD
      b:
        foo "bar"
      =======
      c:
        bar "foo"
      >>>>>>> branch-a

      d:
        yes "no"

      <<<<<<< HEAD
      e:
        foo "bar"
      =======
      f:
        bar "foo"
      >>>>>>> branch-b
      """

      expected_result = %{
        "a" => %{"no" => "yes"},
        "b" => %{"foo" => "bar"},
        "c" => %{"bar" => "foo"},
        "d" => %{"yes" => "no"},
        "e" => %{"foo" => "bar"},
        "f" => %{"bar" => "foo"}
      }

      {:ok, type, result} = ExYarn.parse(input)
      assert :merge == type
      assert expected_result == result
    end

    test "parse merge conflict fail" do
      input = """
      <<<<<<< HEAD
      b:
        foo: "bar
      =======
      c:
        bar "foo"
      >>>>>>> branch-a
      """

      {success?, type, _result} = ExYarn.parse(input)
      assert :error == success?
      assert :conflict == type
    end

    test "discards common ancestors in merge conflicts" do
      input = """
      <<<<<<< HEAD
      b:
        foo "bar"
      ||||||| common ancestor
      d:
        yes "no"
      =======
      c:
        bar "foo"
      >>>>>>> branch-a
      """

      expected_result = %{
        "b" => %{"foo" => "bar"},
        "c" => %{"bar" => "foo"}
      }

      {:ok, type, result} = ExYarn.parse(input)
      assert :merge == type
      assert expected_result == result
    end

    test "parses comments correctly" do
      input = """
      # THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.
      # yarn lockfile v1

      "foo":
        bar foo
      """

      {:ok, :success, result} = ExYarn.parse(input)
      expected_result = %{"foo" => %{"bar" => "foo"}}
      assert expected_result == result
    end
  end
end
