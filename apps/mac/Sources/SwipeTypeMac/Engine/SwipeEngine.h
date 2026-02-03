//
//  SwipeEngine.h
//  SwipeTypeMac
//
//  C FFI header for bridging Rust swipe-engine library to Swift
//

#ifndef SwipeEngine_h
#define SwipeEngine_h

#include <stdint.h>

/// Load dictionary from a file path
/// Returns the number of words loaded, or -1 on error
int32_t swipe_engine_load_dictionary(const char *path);

/// Load dictionary from string content
/// Returns the number of words loaded, or -1 on error
int32_t swipe_engine_load_dictionary_str(const char *content);

/// Get the number of words in the dictionary
int32_t swipe_engine_word_count(void);

/// Predict words from swipe input (format: "x1,y1;x2,y2;...")
/// Returns a JSON string with predictions array
/// Caller must free with swipe_engine_free_string
char *swipe_engine_predict(const char *input, int32_t limit);

/// Free a string returned by the engine
void swipe_engine_free_string(char *s);

/// Set the popularity weight (0.0 to 1.0)
void swipe_engine_set_pop_weight(double weight);

#endif /* SwipeEngine_h */
