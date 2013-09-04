db = connect("localhost:27017/ws-epitech");
db.cache.ensureIndex({ttl:1},{expireAfterSeconds:0});
