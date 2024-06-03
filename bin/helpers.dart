import "package:yaml/yaml.dart";

Map<String, dynamic> convertYamlToMap(YamlMap yamlMap) {
  final map = <String, dynamic>{};

  for (final key in yamlMap.keys) {
    if (yamlMap[key] is YamlMap) {
      map[key] = convertYamlToMap(yamlMap[key]);
    } else if (yamlMap[key] is YamlList) {
      map[key] = convertYamlToList(yamlMap[key]);
    } else {
      map[key] = yamlMap[key];
    }
  }

  return map;
}

List<dynamic> convertYamlToList(YamlList yamlList) {
  final list = <dynamic>[];

  for (final element in yamlList) {
    if (element is YamlMap) {
      list.add(convertYamlToMap(element));
    } else if (element is YamlList) {
      list.add(convertYamlToList(element));
    } else {
      list.add(element);
    }
  }

  return list;
}
