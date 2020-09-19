defmodule LockfileTest do
  use ExUnit.Case, async: true

  alias ExYarn.Lockfile
  alias ExYarn.Lockfile.Dependency
  alias ExYarn.Parsing.ParseError

  @dependency_name "dep_name"
  @parse_result {
    %{
      @dependency_name => %{
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
    },
    [" yarn lockfile v1"]
  }
  @lockfile %Lockfile{
    version: 1,
    dependencies: [
      %Dependency{
        name: @dependency_name,
        version: "42",
        resolved: "npm",
        integrity: "sha512",
        dependencies: [{"sub_dep", "3"}],
        optional_dependencies: [{"opt_dep", "0"}]
      }
    ],
    comments: [" yarn lockfile v1"]
  }

  describe "from_parse_result!/1" do
    test "should return a lockfile" do
      result = Lockfile.from_parse_result!(@parse_result)

      assert @lockfile == result
    end

    test "given an unsupported lockfile version comment, should raise an error" do
      {result_map, _} = @parse_result
      parse_result = {result_map, ["yarn lockfile v2"]}

      assert_raise RuntimeError, fn ->
        Lockfile.from_parse_result!(parse_result)
      end
    end

    test "given no lockfile version comment, should build a lockfile" do
      {result_map, _} = @parse_result
      parse_result = {result_map, []}
      expected_lockfile = %Lockfile{@lockfile | comments: [], version: nil}

      result = Lockfile.from_parse_result!(parse_result)

      assert expected_lockfile == result
    end
  end

  describe "from_parse_result/1" do
    test "should return a lockfile" do
      {:ok, result} = Lockfile.from_parse_result(@parse_result)

      assert @lockfile == result
    end

    test "given an unsupported lockfile version comment, should return an error tuple" do
      {result_map, _} = @parse_result
      parse_result = {result_map, ["yarn lockfile v2"]}

      result = Lockfile.from_parse_result(parse_result)

      assert {:error, _} = result
    end

    test "given no lockfile version comment, should build a lockfile" do
      {result_map, _} = @parse_result
      parse_result = {result_map, []}
      expected_lockfile = %Lockfile{@lockfile | comments: [], version: nil}

      {:ok, result} = Lockfile.from_parse_result(parse_result)

      assert expected_lockfile == result
    end
  end

  describe "from_file!/1" do
    test "should return a lockfile" do
      result = Lockfile.from_file!(build_lockfile_path("valid"))

      assert @lockfile == result
    end

    test "given an unsupported lockfile version comment, should raise an error" do
      assert_raise ParseError, fn ->
        Lockfile.from_file!(build_lockfile_path("invalid_version"))
      end
    end

    test "given no lockfile version comment, should build a lockfile" do
      expected_lockfile = %Lockfile{@lockfile | comments: [], version: nil}

      result = Lockfile.from_file!(build_lockfile_path("no_version"))

      assert expected_lockfile == result
    end
  end

  describe "from_file/1" do
    test "should return a lockfile" do
      {:ok, result} = Lockfile.from_file(build_lockfile_path("valid"))

      assert @lockfile == result
    end

    test "given an unsupported lockfile version comment, should return an error tuple" do
      result = Lockfile.from_file(build_lockfile_path("invalid_version"))

      assert {:error, _} = result
    end

    test "given no lockfile version comment, should build a lockfile" do
      expected_lockfile = %Lockfile{@lockfile | comments: [], version: nil}

      {:ok, result} = Lockfile.from_file(build_lockfile_path("no_version"))

      assert expected_lockfile == result
    end
  end

  defp build_lockfile_path(filename) do
    Path.join("lockfiles", "#{filename}.lock")
  end
end
