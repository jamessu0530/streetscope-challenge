enum GameRegion {
  world,
  asia,
  europe,
  africa,
  northAmerica,
  southAmerica,
  oceania,
  taiwan,
}

extension GameRegionX on GameRegion {
  String get label {
    switch (this) {
      case GameRegion.world:
        return '世界';
      case GameRegion.asia:
        return '亞洲';
      case GameRegion.europe:
        return '歐洲';
      case GameRegion.africa:
        return '非洲';
      case GameRegion.northAmerica:
        return '北美洲';
      case GameRegion.southAmerica:
        return '南美洲';
      case GameRegion.oceania:
        return '大洋洲';
      case GameRegion.taiwan:
        return '台灣';
    }
  }

  String get description {
    switch (this) {
      case GameRegion.world:
        return '全球隨機（內陸優先）';
      case GameRegion.asia:
        return '只出亞洲地區';
      case GameRegion.europe:
        return '只出歐洲地區';
      case GameRegion.africa:
        return '只出非洲地區';
      case GameRegion.northAmerica:
        return '只出北美洲地區';
      case GameRegion.southAmerica:
        return '只出南美洲地區';
      case GameRegion.oceania:
        return '只出大洋洲地區';
      case GameRegion.taiwan:
        return '只出台灣街景';
    }
  }
}
