const conversionSamples = {
    anInt: 1234,
    aBool: true,
    anotherBool: false,
    aDouble: 3.14,
    aString: "booya",
	aNull: null,
    anArray: [
        new EdgeFunction(),
        "test1",
        "test2",
        "test3",
        [
            "blah1",
            "blah2",
            "blah3"
        ],
        {
            anInt: 1234,
            aBool: true,
            anotherBool: false,
            aDouble: 3.14,
            aString: "booya"
        }
    ],
    aDictionary: {
        anInt: 1234,
        aBool: true,
        anotherBool: false,
        aDouble: 3.14,
        aString: "booya",
        anArray: [
            "test1",
            "test2",
            "test3"
        ],
        aDictionary: {
            anInt: 1234,
            aBool: true,
            anotherBool: false,
            aDouble: 3.14,
            anEdgeFn: new EdgeFunction(),
            aString: "booya",
            anArray: [
                "test1",
                "test2",
                "test3",
                [
                    "blah1",
                    "blah2",
                    "blah3"
                ],
            ]
        }
    }
};
