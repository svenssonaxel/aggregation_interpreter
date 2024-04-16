all: \
 ParseCompileTest \
 APICompileTest \


RestSQLParser.y.cpp RestSQLParser.y.hpp: \
 DynamicArray.hpp \
 Makefile \
 RestSQLParser.y \
 RestSQLPreparer.hpp \

	bison RestSQLParser.y

RestSQLLexer.l.with-yy_hold_char.cpp RestSQLLexer.l.hpp: \
 DynamicArray.hpp \
 Makefile \
 RestSQLLexer.l \
 RestSQLParser.y.hpp \
 RestSQLPreparer.hpp \

	flex RestSQLLexer.l

# flex temporarily inserts a null byte after each token it scans so that the
# user can comfortably use the token as a null-terminated C string. We don't
# need that, and we also don't want it, for two reasons:
# 1) In case of a parse error, we can't use the underlying buffer to print the
#    entire SQL statement since it may have a null byte somewhere in the middle.
# 2) Unnecessarily saving a character, writing a null byte and restoring it, for
#    every token, could have a slight performance impact.
# Unfortunately, flex does not provide an option to turn off this feature.
# Fortunately, removing this unwanted feature from the flex output in an
# incredibly hacky way is both possible and easy, so that's what we'll do.
RestSQLLexer.l.cpp: RestSQLLexer.l.with-yy_hold_char.cpp
	sed -r "/yy_hold_char/d; / = '.0';/d;" $< > $@

RestSQLParser.y.o: RestSQLParser.y.cpp \
 AggregationAPICompiler.hpp \
 DynamicArray.hpp \
 LexString.hpp \
 RestSQLLexer.l.hpp \
 RestSQLParser.y.hpp \
 RestSQLPreparer.hpp \

	g++ -c -o $@ $<

RestSQLLexer.l.o: RestSQLLexer.l.cpp \
 DynamicArray.hpp \
 RestSQLParser.y.hpp \
 RestSQLPreparer.hpp \

	g++ -c -o $@ $<

RestSQLPreparer.o: RestSQLPreparer.cpp \
 AggregationAPICompiler.hpp \
 ArenaAllocator.hpp \
 DynamicArray.hpp \
 LexString.hpp \
 RestSQLLexer.l.hpp \
 RestSQLParser.y.hpp \
 RestSQLPreparer.hpp \

	g++ -c -o $@ $<

AggregationAPICompiler.o: AggregationAPICompiler.cpp \
 AggregationAPICompiler.hpp \
 ArenaAllocator.hpp \
 DynamicArray.hpp \
 LexString.hpp \

	g++ -c -o $@ $<

LexString.o: LexString.cpp \
 LexString.hpp \

	g++ -c -o $@ $<

ArenaAllocator.o: ArenaAllocator.cpp \
 ArenaAllocator.hpp \

	g++ -c -o $@ $<

ParseCompileTest: ParseCompileTest.cpp \
 AggregationAPICompiler.hpp \
 AggregationAPICompiler.o \
 ArenaAllocator.hpp \
 ArenaAllocator.o \
 DynamicArray.hpp \
 LexString.hpp \
 LexString.o \
 RestSQLLexer.l.o \
 RestSQLParser.y.o \
 RestSQLPreparer.hpp \
 RestSQLPreparer.o \

	g++ -o $@ $< \
	 AggregationAPICompiler.o \
	 RestSQLPreparer.o \
	 RestSQLParser.y.o \
	 RestSQLLexer.l.o \
	 LexString.o \
	 ArenaAllocator.o

APICompileTest: APICompileTest.cpp \
 AggregationAPICompiler.hpp \
 AggregationAPICompiler.o \
 ArenaAllocator.hpp \
 ArenaAllocator.o \
 DynamicArray.hpp \
 LexString.hpp \
 LexString.o \
 RestSQLPreparer.hpp \

	g++ -o $@ $< AggregationAPICompiler.o LexString.o ArenaAllocator.o

clean:
	rm -f ParseCompileTest APICompileTest *.o *.y.* *.l.*
