import 'package:json_annotation/json_annotation.dart';

part 'deezer_models.g.dart';

class DeezerTrack {
  final int id;
  final String title;
  @JsonKey(name: 'title_short')
  final String titleShort;
  @JsonKey(name: 'title_version')
  final String? titleVersion;
  final String? link;
  final int duration;
  final int? rank;
  @JsonKey(name: 'explicit_lyrics')
  final bool explicitLyrics;
  @JsonKey(name: 'explicit_content_lyrics')
  final int explicitContentLyrics;
  @JsonKey(name: 'explicit_content_cover')
  final int explicitContentCover;
  final String? preview;
  final DeezerArtist? artist;
  final DeezerAlbum? album;
  @JsonKey(name: 'type')
  final String type;

  DeezerTrack({
    required this.id,
    required this.title,
    required this.titleShort,
    this.titleVersion,
    this.link,
    required this.duration,
    this.rank,
    this.explicitLyrics = false,
    this.explicitContentLyrics = 0,
    this.explicitContentCover = 0,
    this.preview,
    this.artist,
    this.album,
    this.type = 'track',
  });

  factory DeezerTrack.fromJson(Map<String, dynamic> json) =>
      _$DeezerTrackFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerTrackToJson(this);
}

@JsonSerializable()
class DeezerArtist {
  final int id;
  final String name;
  final String? link;
  final String? picture;
  @JsonKey(name: 'picture_medium')
  final String? pictureMedium;
  @JsonKey(name: 'picture_xl')
  final String? pictureXl;
  final int? nbFan;
  @JsonKey(name: 'radio')
  final bool? radio;
  final String? type;

  DeezerArtist({
    required this.id,
    required this.name,
    this.link,
    this.picture,
    this.pictureMedium,
    this.pictureXl,
    this.nbFan,
    this.radio,
    this.type,
  });

  factory DeezerArtist.fromJson(Map<String, dynamic> json) =>
      _$DeezerArtistFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerArtistToJson(this);
}

@JsonSerializable()
class DeezerAlbum {
  final int id;
  final String title;
  final String? link;
  final String? cover;
  @JsonKey(name: 'cover_medium')
  final String? coverMedium;
  @JsonKey(name: 'cover_xl')
  final String? coverXl;
  final String? genreId;
  @JsonKey(name: 'Fans')
  final int? fans;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  final String? recordType;
  final DeezerArtist? artist;
  final String? type;

  DeezerAlbum({
    required this.id,
    required this.title,
    this.link,
    this.cover,
    this.coverMedium,
    this.coverXl,
    this.genreId,
    this.fans,
    this.releaseDate,
    this.recordType,
    this.artist,
    this.type,
  });

  factory DeezerAlbum.fromJson(Map<String, dynamic> json) =>
      _$DeezerAlbumFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerAlbumToJson(this);
}

@JsonSerializable()
class DeezerPlaylist {
  final int id;
  final String title;
  final String? description;
  final int? duration;
  final bool? public;
  @JsonKey(name: 'nb_tracks')
  final int? nbTracks;
  final String? link;
  final String? picture;
  @JsonKey(name: 'picture_medium')
  final String? pictureMedium;
  @JsonKey(name: 'picture_xl')
  final String? pictureXl;
  @JsonKey(name: 'checksum')
  final String? checksum;
  final DeezerUser? creator;
  final String? type;

  DeezerPlaylist({
    required this.id,
    required this.title,
    this.description,
    this.duration,
    this.public,
    this.nbTracks,
    this.link,
    this.picture,
    this.pictureMedium,
    this.pictureXl,
    this.checksum,
    this.creator,
    this.type,
  });

  factory DeezerPlaylist.fromJson(Map<String, dynamic> json) =>
      _$DeezerPlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerPlaylistToJson(this);
}

@JsonSerializable()
class DeezerUser {
  final int id;
  final String name;
  final String? lastname;
  final String? firstname;
  final String? email;
  final String? picture;
  @JsonKey(name: 'picture_medium')
  final String? pictureMedium;
  final int? country;
  final String? lang;
  final bool? isKid;
  final String? type;

  DeezerUser({
    required this.id,
    required this.name,
    this.lastname,
    this.firstname,
    this.email,
    this.picture,
    this.pictureMedium,
    this.country,
    this.lang,
    this.isKid,
    this.type,
  });

  factory DeezerUser.fromJson(Map<String, dynamic> json) =>
      _$DeezerUserFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerUserToJson(this);
}

@JsonSerializable()
class DeezerChart {
  @JsonKey(name: 'tracks')
  final List<DeezerTrack>? tracks;
  @JsonKey(name: 'albums')
  final List<DeezerAlbum>? albums;
  @JsonKey(name: 'artists')
  final List<DeezerArtist>? artists;
  @JsonKey(name: 'playlists')
  final List<DeezerPlaylist>? playlists;

  DeezerChart({this.tracks, this.albums, this.artists, this.playlists});

  factory DeezerChart.fromJson(Map<String, dynamic> json) =>
      _$DeezerChartFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerChartToJson(this);
}

@JsonSerializable()
class DeezerRecommendations {
  final List<DeezerTrack> data;
  final dynamic total;

  DeezerRecommendations({required this.data, this.total});

  factory DeezerRecommendations.fromJson(Map<String, dynamic> json) =>
      _$DeezerRecommendationsFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerRecommendationsToJson(this);
}

enum SearchFilter { tracks, albums, artists }

// ---- Genre (legacy alias for generated code compatibility) ----

@JsonSerializable()
class DeeGenre {
  final int id;
  final String name;
  final String? picture;

  DeeGenre({
    required this.id,
    required this.name,
    this.picture,
  });

  factory DeeGenre.fromJson(Map<String, dynamic> json) =>
      _$DeeGenreFromJson(json);

  Map<String, dynamic> toJson() => _$DeeGenreToJson(this);
}

// ---- OAuth Token ----

@JsonSerializable()
class DeeAuthToken {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;

  DeeAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  factory DeeAuthToken.fromJson(Map<String, dynamic> json) =>
      _$DeeAuthTokenFromJson(json);

  Map<String, dynamic> toJson() => _$DeeAuthTokenToJson(this);
}

// ---- Genre ----

@JsonSerializable()
class DeezerGenre {
  final int id;
  final String name;
  final String? picture;

  DeezerGenre({
    required this.id,
    required this.name,
    this.picture,
  });

  factory DeezerGenre.fromJson(Map<String, dynamic> json) =>
      _$DeezerGenreFromJson(json);

  Map<String, dynamic> toJson() => _$DeezerGenreToJson(this);
}
