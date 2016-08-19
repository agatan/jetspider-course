function MyObject(i) {
    this.index = i;
}
var first = new MyObject(one);
var second = new MyObject(two);
p(first.index);
p(second.index);
first.index = 3;
p("first.index = 3;");
p(first.index);
p(second.index);
p("increment...");
p(first.index++);
p(first.index);

function f() {
    return one;
}

first.m = f;
p(first.m());

function g() {
    return this.index;
}
first.g = g;
p(first.g());
