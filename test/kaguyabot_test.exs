defmodule KaguyabotTest do
  use ExUnit.Case
  doctest Kaguyabot

  test "greets the world" do
    assert Kaguyabot.hello() == :world
  end
end
