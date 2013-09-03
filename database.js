db = connect("localhost:27017/ws-epitech");
db.urlCache.ensureIndex({ttl:1},{expireAfterSeconds:0});
