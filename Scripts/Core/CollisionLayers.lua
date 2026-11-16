CollisionLayers = {}

CollisionLayers.Environment = 0x02
CollisionLayers.Enemy = 0x04
CollisionLayers.Stone = 0x08
CollisionLayers.Solid = CollisionLayers.Environment + CollisionLayers.Stone
