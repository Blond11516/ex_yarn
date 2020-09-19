defmodule ExYarnTest do
  use ExUnit.Case, async: true

  alias ExYarn.{Dependency, Lockfile, ParseError}

  doctest ExYarn

  @expected_valid_results %{
    "dep_name" => %{
      "version" => "42",
      "resolved" => "npm",
      "integrity" => "sha512",
      "dependencies" => %{
        "sub_dep" => "3"
      },
      "optionalDependencies" => %{
        "opt_dep" => "0"
      }
    }
  }
  @expected_valid_comments [" yarn lockfile v1"]
  @expected_valid_lockfile %Lockfile{
    version: 1,
    dependencies: [
      %Dependency{
        name: "dep_name",
        version: "42",
        resolved: "npm",
        integrity: "sha512",
        dependencies: [{"sub_dep", "3"}],
        optional_dependencies: [{"opt_dep", "0"}]
      }
    ],
    comments: @expected_valid_comments
  }
  @invalid_content "some invalid content"

  describe "parse/1" do
    test "given a valid input, should return the parsed map and comments" do
      {:ok, {result, comments}} =
        read_test_file("valid")
        |> ExYarn.parse()

      assert result == @expected_valid_results
      assert comments == @expected_valid_comments
    end

    test "given an input with unsupported version, should return an error" do
      {:error, _} =
        read_test_file("invalid_version")
        |> ExYarn.parse()
    end

    test "given invalid input, should return an error" do
      {:error, _} = ExYarn.parse(@invalid_content)
    end
  end

  describe "parse!/1" do
    test "given a valid input, should return the parsed map and comments" do
      {result, comments} =
        read_test_file("valid")
        |> ExYarn.parse!()

      assert result == @expected_valid_results
      assert comments == @expected_valid_comments
    end

    test "given an input with unsupported version, should raise an error" do
      assert_raise ParseError, fn ->
        read_test_file("invalid_version")
        |> ExYarn.parse!()
      end
    end

    test "given invalid input, should raise an error" do
      assert_raise ParseError, fn ->
        ExYarn.parse!(@invalid_content)
      end
    end
  end

  describe "parse_to_lockfile/1" do
    test "given a valid input, should return a lockfile" do
      {:ok, lockfile} =
        read_test_file("valid")
        |> ExYarn.parse_to_lockfile()

      assert lockfile == @expected_valid_lockfile
    end

    test "given an input with unsupported version, should return an error" do
      {:error, _} =
        read_test_file("invalid_version")
        |> ExYarn.parse_to_lockfile()
    end

    test "given invalid input, should return an error" do
      {:error, _} = ExYarn.parse_to_lockfile(@invalid_content)
    end
  end

  describe "parse_to_lockfile!/1" do
    test "given a valid input, should return a lockfile" do
      lockfile =
        read_test_file("valid")
        |> ExYarn.parse_to_lockfile!()

      assert lockfile == @expected_valid_lockfile
    end

    test "given an input with unsupported version, should raise an error" do
      assert_raise ParseError, fn ->
        read_test_file("invalid_version")
        |> ExYarn.parse_to_lockfile!()
      end
    end

    test "given invalid input, should raise an error" do
      assert_raise ParseError, fn ->
        ExYarn.parse_to_lockfile!(@invalid_content)
      end
    end
  end

  defp read_test_file(filename) do
    Path.join("lockfiles", "#{filename}.lock")
    |> File.read()
    |> Kernel.elem(1)
  end
end
