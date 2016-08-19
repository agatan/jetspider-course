function f(x) {
    var count = x;
    return function() {
        return count++;
    };
}

var l = f(3);
p(l());
p(l());

