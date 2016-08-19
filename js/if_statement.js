function f(n) {
    var x = n;
    if (x) {
        return 1;
    } else {
        return 0;
    }
}

function f2(n) {
    var x = n;
    if (x) {
        return 1;
    }
}

p(f(1));
p(f(0));
p(f2(1));
p(f2(0));
