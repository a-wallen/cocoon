// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: always_specify_types, implicit_dynamic_parameter

part of 'commit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GerritCommit _$GerritCommitFromJson(Map<String, dynamic> json) => GerritCommit(
      commit: json['commit'] as String?,
      tree: json['tree'] as String?,
      author: json['author'] == null ? null : GerritUser.fromJson(json['author'] as Map<String, dynamic>),
      comitter: json['comitter'] == null ? null : GerritUser.fromJson(json['comitter'] as Map<String, dynamic>),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$GerritCommitToJson(GerritCommit instance) => <String, dynamic>{
      'commit': instance.commit,
      'tree': instance.tree,
      'author': instance.author,
      'comitter': instance.comitter,
      'message': instance.message,
    };

GerritUser _$GerritUserFromJson(Map<String, dynamic> json) => GerritUser(
      name: json['name'] as String?,
      email: json['email'] as String?,
      time: GerritUser._dateTimeFromGerritTime(json['time'] as String),
    );

Map<String, dynamic> _$GerritUserToJson(GerritUser instance) => <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'time': instance.time?.toIso8601String(),
    };