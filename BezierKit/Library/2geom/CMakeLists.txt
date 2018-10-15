#generate parser file with ragel
SET(SVG_PARSER_CPP "${CMAKE_CURRENT_SOURCE_DIR}/svg-path-parser.cpp")
SET(SVG_PARSER_TMP "${CMAKE_CURRENT_SOURCE_DIR}/svg-path-parser.tmp")
SET(SVG_PARSER_RL "${CMAKE_CURRENT_SOURCE_DIR}/svg-path-parser.rl")
SET(GENERATE_SVG_PARSER NOT EXISTS "${SVG_PARSER_CPP}")
SET(REGENERATE_SVG_PARSER "${SVG_PARSER_CPP}" IS_NEWER_THAN "${SVG_PARSER_RL}")
find_program(RAGEL_PROGRAM
   NAMES ragel
         ragel.exe
   DOC "Find ragel program"
   HINTS /usr/bin
         /usr/local/bin
         ${RAGEL_BIN}
         ${MINGW_BIN}
)
IF( RAGEL_PROGRAM )
IF(GENERATE_SVG_PARSER OR REGENERATE_SVG_PARSER)
  ADD_CUSTOM_COMMAND(OUTPUT "${SVG_PARSER_CPP}"
                     COMMAND ${RAGEL_PROGRAM} -C -T0 -o "${SVG_PARSER_CPP}" "${SVG_PARSER_RL}"
                     DEPENDS "${SVG_PARSER_RL}"
                     WORKING_DIRECTORY "${CURRENT_SOURCE_DIR}"
                     COMMENT "Generating svg_path_parser.cpp with ragel"
                     )
ENDIF(GENERATE_SVG_PARSER OR REGENERATE_SVG_PARSER)
ENDIF( RAGEL_PROGRAM )

SET(2GEOM_SRC

affine.cpp
affine.h
angle.h

basic-intersection.cpp
basic-intersection.h
bezier.cpp
bezier.h
bezier-clipping.cpp
bezier-curve.cpp
bezier-curve.h
bezier-to-sbasis.h
bezier-utils.cpp
bezier-utils.h

cairo-path-sink.h
cairo-path-sink.cpp
choose.h
circle.cpp
circle.h
concepts.cpp
concepts.h
conicsec.cpp
conicsec.h
conic_section_clipper.h
conic_section_clipper_cr.h
conic_section_clipper_impl.cpp
conic_section_clipper_impl.h
convex-hull.cpp
convex-hull.h
coord.cpp
coord.h
crossing.cpp
crossing.h
curve.cpp
curve.h
curves.h

d2-sbasis.cpp
d2.h

ellipse.cpp
ellipse.h
elliptical-arc.cpp
elliptical-arc.h
elliptical-arc-from-sbasis.cpp
exception.h

forward.h

geom.cpp
geom.h

intersection.h
intersection-graph.cpp
intersection-graph.h

line.cpp
line.h
linear.h

math-utils.h

nearest-time.cpp
nearest-time.h

numeric/matrix.cpp

ord.h

path-intersection.cpp
path-intersection.h
path-sink.cpp
path-sink.h
path.cpp
path.h
pathvector.cpp
pathvector.h
piecewise.cpp
piecewise.h
point.cpp
point.h
polynomial.cpp
polynomial.h

ray.h
rect.h
rect.cpp
recursive-bezier-intersection.cpp

sbasis-2d.cpp
sbasis-2d.h
sbasis-curve.h
sbasis-geometric.cpp
sbasis-geometric.h
sbasis-math.cpp
sbasis-math.h
sbasis-poly.cpp
sbasis-poly.h
sbasis-roots.cpp
sbasis-to-bezier.cpp
sbasis-to-bezier.h
sbasis.cpp
sbasis.h
solve-bezier.cpp
solve-bezier-one-d.cpp
solve-bezier-parametric.cpp
solver.h
svg-path-parser.cpp
svg-path-parser.h
svg-path-writer.cpp
svg-path-writer.h
sweeper.h
sweep-bounds.cpp
sweep-bounds.h

transforms.cpp
transforms.h

utils.cpp
utils.h
)

# make lib for 2geom
ADD_LIBRARY(2geom ${LIB_TYPE} ${2GEOM_SRC})
TARGET_LINK_LIBRARIES(2geom "${LINK_GSL}" "${GTK2_LINK_FLAGS}")
SET_TARGET_PROPERTIES(2geom PROPERTIES SOVERSION "${2GEOM_ABI_VERSION}")
INSTALL(TARGETS 2geom
  RUNTIME DESTINATION bin
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)
FILE(GLOB files "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
INSTALL(FILES ${files} DESTINATION include/2geom-${2GEOM_VERSION}/2geom)
INSTALL(FILES ${CMAKE_BINARY_DIR}/config.h DESTINATION include/2geom-${2GEOM_VERSION}/2geom)
FILE(GLOB files "${CMAKE_CURRENT_SOURCE_DIR}/numeric/*.h")
INSTALL(FILES ${files} DESTINATION include/2geom-${2GEOM_VERSION}/2geom/numeric)

CONFIGURE_FILE( ${CMAKE_SOURCE_DIR}/2geom.pc.in
                ${CMAKE_BINARY_DIR}/2geom.pc @ONLY IMMEDIATE )
INSTALL(FILES "${CMAKE_BINARY_DIR}/2geom.pc" DESTINATION lib/pkgconfig)

