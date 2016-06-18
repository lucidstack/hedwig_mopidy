defmodule HedwigMopidy.Responders.Playback do
  use Hedwig.Responder

  hear ~r/play artist (?<artist>.*)/i, message do
    artist = message.matches["artist"]

    response = 
      with {:ok, %Mopidy.SearchResult{} = search_results} <- Mopidy.Library.search(%{artist: [artist]}),
           {:ok, :success} <- Mopidy.Tracklist.clear,
           {:ok, tracks} when is_list(tracks) <- Mopidy.Tracklist.add(search_results.tracks |> Enum.map(fn(%Mopidy.Track{} = track) -> track.uri end)),
           {:ok, :success} <- Mopidy.Playback.play do
        "♫ Playing music by " <> String.capitalize(artist)
      else
        {:error, error_message} -> error_message
        _ ->
          case Mopidy.Tracklist.get_length do
            {:ok, 0} -> "✗ Couldn't find any music for that artist"
            _        -> "✗ Couldn't play music by that artist"
          end
      end

    send message, response
  end

  hear ~r/play album (?<album>.*) by (?<artist>.*)/i, message do
    album = message.matches["album"]
    artist = message.matches["artist"]

    response = 
      with {:ok, %Mopidy.SearchResult{} = search_results} <- Mopidy.Library.search(%{artist: [artist], album: [album]}),
           {:ok, :success} <- Mopidy.Tracklist.clear,
           {:ok, tracks} when is_list(tracks) <- Mopidy.Tracklist.add(search_results.tracks |> Enum.map(fn(%Mopidy.Track{} = track) -> track.uri end)),
           {:ok, :success} <- Mopidy.Playback.play do
        "♫ Playing " <> String.capitalize(album) <> " by " <> String.capitalize(artist)
      else
        {:error, error_message} -> error_message
        _ ->
          case Mopidy.Tracklist.get_length do
            {:ok, 0} -> "✗ Couldn't find any music for that album"
            _        -> "✗ Couldn't play music for that album"
          end
      end

    send message, response
  end

  hear ~r/(who is|who's) playing/i, message do
    response = 
      with {:ok, current_track} <- Mopidy.Playback.get_current_track do
        case current_track do
          %Mopidy.Track{} = track -> HedwigMopidy.playing_string(track)
          _ -> "■ Nothing is playing"
        end
      else
        {:error, error_message} -> error_message
        _ -> "✗ Couldn't find who's playing"
      end

    send message, response
  end

  hear ~r/play/i, message do
    response = 
      with {:ok, :success} <- Mopidy.Playback.play,
           {:ok, current_track} <- Mopidy.Playback.get_current_track do
        case current_track do
          %Mopidy.Track{} = track -> HedwigMopidy.playing_string(track)
          _ -> "► No songs to play"
        end
      else
        {:error, error_message} -> error_message
        _ -> "✗ Couldn't play music"
      end

    send message, response
  end

  hear ~r/stop/i, message do
    response = 
      with {:ok, :success} <- Mopidy.Playback.stop do
        "■ Stopped"
      else
        {:error, error_message} -> error_message
        _ -> "✗ Couldn't stop music"
      end

    send message, response
  end

  hear ~r/pause/i, message do
    response = 
      with {:ok, :success} <- Mopidy.Playback.pause,
           {:ok, state} <- Mopidy.Playback.get_state,
           {:ok, current_track} <- Mopidy.Playback.get_current_track do
        case state do
          "playing" -> HedwigMopidy.playing_string(current_track)
          "stopped" -> "Stopped"
          "paused" -> "Paused on " <> HedwigMopidy.track_string(current_track)
          _ -> "✗ Couldn't pause music"
        end
      else
        {:error, error_message} -> error_message
        _ -> "✗ Couldn't pause music"
      end

    send message, response
  end

end
