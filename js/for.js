for (var i = 0; i < 4; i++) {
    p("i: ");
    p(i);
    for (var j = 0; j < 3; j++) {
        if (i * 10 + j == 11) {
            continue;
        }
        p("with j:");
        p(i * 10 + j);
        if (i * 10 + j == 21) {
            break;
        }
    }
}
