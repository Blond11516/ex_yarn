defmodule DependencyTest do
  alias ExYarn.Dependency

  use ExUnit.Case, async: true
  doctest Dependency

  @dependency_name "dep_name"
  @result_map %{
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
  }
  @expected_dep %Dependency{
    name: @dependency_name,
    version: "42",
    resolved: "npm",
    integrity: "sha512",
    dependencies: [{"sub_dep", "3"}],
    optional_dependencies: [{"opt_dep", "0"}]
  }

  describe "from_result_map" do
    test "should build a dependency" do
      dep = Dependency.from_result_map(@result_map)

      assert @expected_dep == dep
    end

    test "given a result map without integrity, integrity should be nil" do
      result_map = remove_from_result_map(@result_map, "integrity")
      expected_dep = %Dependency{@expected_dep | integrity: nil}

      dep = Dependency.from_result_map(result_map)

      assert expected_dep == dep
    end

    test "given a result map without dependencies, dependencies should be empty" do
      result_map = remove_from_result_map(@result_map, "dependencies")
      expected_dep = %Dependency{@expected_dep | dependencies: []}

      dep = Dependency.from_result_map(result_map)

      assert expected_dep == dep
    end

    test "given a result map without optional dependencies, optional dependencies should be empty" do
      result_map = remove_from_result_map(@result_map, "optionalDependencies")
      expected_dep = %Dependency{@expected_dep | optional_dependencies: []}

      dep = Dependency.from_result_map(result_map)

      assert expected_dep == dep
    end
  end

  defp remove_from_result_map(result_map, data_key) do
    dep_name = result_map |> Map.keys() |> List.first()
    dep_data = result_map[dep_name]
    %{dep_name => Map.delete(dep_data, data_key)}
  end
end
