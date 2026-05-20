// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deezer_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeezerTrack _$DeezerTrackFromJson(Map<String, dynamic> json) => DeezerTrack(
      id: json['id'] as int,
      title: json['title'] as String,
      titleShort: json['title_short'] as String? ?? json['title'] as String,
      titleVersion: json['title_version'] as String?,
      link: json['link'] as String?,
      duration: json['duration'] as int,
      rank: json['rank'] as int?,
      explicitLyrics: json['explicit_lyrics'] as bool? ?? false,
      explicitContentLyrics: json['explicit_content_lyrics'] as int? ?? 0,
      explicitContentCover: json['explicit_content_cover'] as int? ?? 0,
      preview: json['preview'] as String?,
      artist: json['artist'] == null
          ? null
          : DeezerArtist.fromJson(json['artist'] as Map<String, dynamic>),
      album: json['album'] == null
          ? null
          : DeezerAlbum.fromJson(json['album'] as Map<String, dynamic>),
      type: json['type'] as String? ?? 'track',
    );

Map<String, dynamic> _$DeezerTrackToJson(DeezerTrack instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'title_short': instance.titleShort,
      'title_version': instance.titleVersion,
      'link': instance.link,
      'duration': instance.duration,
      'rank': instance.rank,
      'explicit_lyrics': instance.explicitLyrics,
      'explicit_content_lyrics': instance.explicitContentLyrics,
      'explicit_content_cover': instance.explicitContentCover,
      'preview': instance.preview,
      'artist': instance.artist?.toJson(),
      'album': instance.album?.toJson(),
      'type': instance.type,
    };

DeezerArtist _$DeezerArtistFromJson(Map<String, dynamic> json) =>
    DeezerArtist(
      id: json['id'] as int,
      name: json['name'] as String,
      link: json['link'] as String?,
      picture: json['picture'] as String?,
      pictureMedium: json['picture_medium'] as String?,
      pictureXl: json['picture_xl'] as String?,
      nbFan: json['nb_fan'] as int?,
      radio: json['radio'] as bool?,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$DeezerArtistToJson(DeezerArtist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'link': instance.link,
      'picture': instance.picture,
      'picture_medium': instance.pictureMedium,
      'picture_xl': instance.pictureXl,
      'nb_fan': instance.nbFan,
      'radio': instance.radio,
      'type': instance.type,
    };

DeezerAlbum _$DeezerAlbumFromJson(Map<String, dynamic> json) => DeezerAlbum(
      id: json['id'] as int,
      title: json['title'] as String,
      link: json['link'] as String?,
      cover: json['cover'] as String?,
      coverMedium: json['cover_medium'] as String?,
      coverXl: json['cover_xl'] as String?,
      genreId: json['genre_id'] as String?,
      fans: json['Fans'] as int?,
      releaseDate: json['release_date'] as String?,
      recordType: json['record_type'] as String?,
      artist: json['artist'] == null
          ? null
          : DeezerArtist.fromJson(json['artist'] as Map<String, dynamic>),
      type: json['type'] as String?,
    );

Map<String, dynamic> _$DeezerAlbumToJson(DeezerAlbum instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'link': instance.link,
      'cover': instance.cover,
      'cover_medium': instance.coverMedium,
      'cover_xl': instance.coverXl,
      'genre_id': instance.genreId,
      'Fans': instance.fans,
      'release_date': instance.releaseDate,
      'record_type': instance.recordType,
      'artist': instance.artist?.toJson(),
      'type': instance.type,
    };

DeezerPlaylist _$DeezerPlaylistFromJson(Map<String, dynamic> json) =>
    DeezerPlaylist(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      duration: json['duration'] as int?,
      public: json['public'] as bool?,
      nbTracks: json['nb_tracks'] as int?,
      link: json['link'] as String?,
      picture: json['picture'] as String?,
      pictureMedium: json['picture_medium'] as String?,
      pictureXl: json['picture_xl'] as String?,
      checksum: json['checksum'] as String?,
      creator: json['creator'] == null
          ? null
          : DeezerUser.fromJson(json['creator'] as Map<String, dynamic>),
      type: json['type'] as String?,
    );

Map<String, dynamic> _$DeezerPlaylistToJson(DeezerPlaylist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'duration': instance.duration,
      'public': instance.public,
      'nb_tracks': instance.nbTracks,
      'link': instance.link,
      'picture': instance.picture,
      'picture_medium': instance.pictureMedium,
      'picture_xl': instance.pictureXl,
      'checksum': instance.checksum,
      'creator': instance.creator?.toJson(),
      'type': instance.type,
    };

DeezerUser _$DeezerUserFromJson(Map<String, dynamic> json) => DeezerUser(
      id: json['id'] as int,
      name: json['name'] as String,
      lastname: json['lastname'] as String?,
      firstname: json['firstname'] as String?,
      email: json['email'] as String?,
      picture: json['picture'] as String?,
      pictureMedium: json['picture_medium'] as String?,
      country: json['country'] as int?,
      lang: json['lang'] as String?,
      isKid: json['is_kid'] as bool?,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$DeezerUserToJson(DeezerUser instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'lastname': instance.lastname,
      'firstname': instance.firstname,
      'email': instance.email,
      'picture': instance.picture,
      'picture_medium': instance.pictureMedium,
      'country': instance.country,
      'lang': instance.lang,
      'is_kid': instance.isKid,
      'type': instance.type,
    };

DeezerChart _$DeezerChartFromJson(Map<String, dynamic> json) => DeezerChart(
      tracks: (json['tracks'] as List<dynamic>?)
          ?.map((e) => DeezerTrack.fromJson(e as Map<String, dynamic>))
          .toList(),
      albums: (json['albums'] as List<dynamic>?)
          ?.map((e) => DeezerAlbum.fromJson(e as Map<String, dynamic>))
          .toList(),
      artists: (json['artists'] as List<dynamic>?)
          ?.map((e) => DeezerArtist.fromJson(e as Map<String, dynamic>))
          .toList(),
      playlists: (json['playlists'] as List<dynamic>?)
          ?.map((e) => DeezerPlaylist.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DeezerChartToJson(DeezerChart instance) => <String, dynamic>{
      'tracks': instance.tracks?.map((e) => e.toJson()),
      'albums': instance.albums?.map((e) => e.toJson()),
      'artists': instance.artists?.map((e) => e.toJson()),
      'playlists': instance.playlists?.map((e) => e.toJson()),
    };

DeezerRecommendations _$DeezerRecommendationsFromJson(
        Map<String, dynamic> json) =>
    DeezerRecommendations(
      data: (json['data'] as List<dynamic>)
          .map((e) => DeezerTrack.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'],
    );

Map<String, dynamic> _$DeezerRecommendationsToJson(
        DeezerRecommendations instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'total': instance.total,
    };

DeeGenre _$DeeGenreFromJson(Map<String, dynamic> json) => DeeGenre(
      id: json['id'] as int,
      name: json['name'] as String,
      picture: json['picture'] as String?,
    );

Map<String, dynamic> _$DeeGenreToJson(DeeGenre instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'picture': instance.picture,
    };

DeeAuthToken _$DeeAuthTokenFromJson(Map<String, dynamic> json) => DeeAuthToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
    );

Map<String, dynamic> _$DeeAuthTokenToJson(DeeAuthToken instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'expires_in': instance.expiresIn,
    };

DeezerGenre _$DeezerGenreFromJson(Map<String, dynamic> json) => DeezerGenre(
      id: json['id'] as int,
      name: json['name'] as String,
      picture: json['picture'] as String?,
    );

Map<String, dynamic> _$DeezerGenreToJson(DeezerGenre instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'picture': instance.picture,
    };