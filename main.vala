/* file: test-gda.vala */
using Gda;

namespace Test {
        class SelectQuery : Object {
            public string field { set; get; default = "*"; }
            public string table { set; get; default = "test"; }
            public Connection connection { set; get; }
            
            public DataModel get_table_contents () 
                throws Error 
                requires (this.connection.is_opened())
            {
                /* Build Select Query */
                var b = new Gda.SqlBuilder(Gda.SqlStatementType.SELECT);
                b.select_add_field (this.field, null, null);
				b.select_add_target(this.table, null);
				var s = b.get_statement();
				var m = this.connection.statement_execute_select(s, null);
				s.unref();
				return m;
            }
        }
        
		class SelectQueryPid : Object {
            public string field { set; get; default = "*"; }
            public string table { set; get; default = "test"; }
            public string pid { set; get; default = "test"; }
            public string field_pid { set; get; default = "pid"; }
            public Connection connection { set; get; }
            
            public DataModel get_table_contents () 
                throws Error 
                requires (this.connection.is_opened())
            {
                /* Build Select Query */
                var b = new Gda.SqlBuilder(Gda.SqlStatementType.SELECT);
                b.select_add_field (this.field, null, null);
				b.select_add_target(this.table, null);
				var cond_id = b.add_cond(Gda.SqlOperatorType.EQ, b.add_field_id (field_pid, table), b.add_expr_value(null, Default.unescape_string(pid)), 0);
				b.set_where(cond_id);
				var s = b.get_statement();
				var m = this.connection.statement_execute_select(s, null);
				s.unref();
				return m;
            }
        }
        
        
		class ClearQuery : Object {
            public string table { set; get; default = "xxxxxx"; }
            public Connection connection { set; get; }
            
            public void clear_table () 
                throws Error 
                requires (this.connection.is_opened())
            {
                stdout.printf("Clearing table '%s'\n", table);
                /* Build Select Query */
                var b = new Gda.SqlBuilder(Gda.SqlStatementType.DELETE);
				b.set_table (this.table);
				var s = b.get_statement();
				this.connection.statement_execute_non_select(s, null, null);
            }
        }
        
        class DataBase : Object {
                /* Using defaults will search a SQLite database located at current directory called test.db */
                public string provider { set; get; default = "SQLite"; }
                public string constr { set; get; default = "DB_DIR=.;DB_NAME=Locations.itdb;APPEND_DB_EXTENSION=FALSE"; }
				public string filename {
					set {
						constr = "DB_DIR=/;DB_NAME=" + value + ";APPEND_DB_EXTENSION=FALSE";
					}
				}

                public Gda.Connection cnn;
                
                public void open () throws Error {
                        this.cnn = Gda.Connection.open_from_string (provider, constr, null, Gda.ConnectionOptions.NONE);
                }

                /* Create a tables and populate them */
                public void create_tables () 
                        throws Error
                        requires (this.cnn.is_opened())
                {
                        stdout.printf("Creating and populating data...\n");
                        this.run_query("CREATE TABLE test (description string, notes string)");
                        this.run_query("INSERT INTO test (description, notes) VALUES (\"Test description 1\", \"Some notes\")");
                        this.run_query("INSERT INTO test (description, notes) VALUES (\"Test description 2\", \"Some additional notes\")");
                        
                        this.run_query("CREATE TABLE table1 (city string, notes string)");
                        this.run_query("INSERT INTO table1 (city, notes) VALUES (\"Mexico\", \"Some place to live\")");
                        this.run_query("INSERT INTO table1 (city, notes) VALUES (\"New York\", \"A new place to live\")");
                }
                
                public int run_query (string query) 
                        throws Error
                        requires (this.cnn.is_opened())
                {
                        return this.cnn.execute_non_select_command (query);
                }
        }

		class ArtistRow : Object {
			public string pid;
			public int64 track_artist_id;
			public string order { set; get; default = "100"; }
			public string name;
			public int album_count {private set; get; default = 1;}
			unowned ItemLocationLinker linker;

			public ArtistRow.with_linker (ItemLocationLinker linker,  string? name, string default_pid, int64 track_artist_id) {
				this.linker = linker;
				
				this.name = name ?? "Unknown";

				pid = default_pid;
				add_to_database ();
				
				this.track_artist_id = track_artist_id;
			}

			public ArtistRow.full (ItemLocationLinker linker, string pid, int64 track_artist_id, string order, string name, int album_count) {
				this.linker = linker;
				this.pid = pid;
				this.track_artist_id = track_artist_id;
				this.order = order;
				this.name = name;
				this.album_count = album_count;
			}

			public void register_album (string album) {
				album_count += 1;
				linker.run_query_library (@"update artist set album_count = '$album_count' where pid = '$pid'");
			}

			public void assign_order (string order) {
				this.order = order;
				linker.run_query_library (@"update artist set name_order = '$order' where pid = '$pid'");
				linker.run_query_library (@"update album set artist_order = '$order' where artist_pid = '$pid'");
			}
			
			void add_to_database () {
				linker.run_query_library (@"insert into artist (\"pid\", \"kind\", \"artwork_status\", \"artwork_album_pid\", \"name\", \"name_order\", \"sort_name\", \"album_count\", has_songs) values ('$pid', '2', '0', '0', '$name', '100', '$name', '$album_count', 1)");

			}

			public void save_to_database () {
				linker.run_query_library (@"insert into track_artist (pid, name, name_order, sort_name, has_songs, album_count) values ($track_artist_id, '$name', $order, '$name', 1, $album_count)");
				linker.run_query_library (@"update item set track_artist_pid = $(track_artist_id) where artist_pid = $pid");
			}
			
		}

		class LocationRow : Object {
			public string filename;
			public uint64 duration;
			public string artist;
			public string album;
			public string title;
			ItemLocationLinker linker;
			public string album_pid;
			public string item_pid;
			public ArtistRow artist_row;
			public int track;
			public int track_count;

			CharsetConverter charset;

			construct {
				charset = new CharsetConverter ("UTF-8", "ISO-8859-1");
			}

			public LocationRow.create_with_linker (ItemLocationLinker linker, string path) {
				this.linker = linker;
				item_pid = linker.peek_unused_location_id ();
				filename = linker.filename_for_id(item_pid);
				title = path;

			}

			public void copy_file (string basis, string file) {
				var f = File.new_for_path(file);
				var f2 = File.new_for_path(basis + "/iPod_Control/Music/" + filename);
				f.copy(f2, FileCopyFlags.OVERWRITE);
			}

			public void load_id3_tags (string file) {
#if UNDEF
				var f = new Id3Tag.File (file, Id3Tag.FileMode.READONLY);
				var t = f.tag ();
				foreach(var fr in t.frames) {
					string? data = null;
					foreach(var field_id in fr.fields) {
						var field = fr.field(1);
						if(field != null) {
							switch(field.type) {
								case Id3Tag.FieldType.STRINGLIST:
									data = "";
									for(int i = 0; field.getstrings(i) != null; i++)
										data += (string)(Id3Tag.UCS4.utf8duplicate(field.getstrings(i)));
									break;
								case Id3Tag.FieldType.BINARYDATA:
									debug("binary data for %s\n", fr.description);
									break;
								case Id3Tag.FieldType.LATIN1:
									debug("latin1 data for %s\n", fr.description);
									break;
								case Id3Tag.FieldType.LATIN1FULL:
									debug("latin1 data for %s\n", fr.description);
									break;
								case Id3Tag.FieldType.LATIN1LIST:
									debug("latin1 data for %s\n", fr.description);
									break;
								case Id3Tag.FieldType.STRINGFULL:
									debug("stringfull data for %s\n", fr.description);
									break;
								case Id3Tag.FieldType.STRING:
									debug("stringfull data for %s\n", fr.description);
									break;
								case Id3Tag.FieldType.LANGUAGE:
									debug("language data for %s\n", fr.description);
									break;
								default:
									error("not handled %d for %s", field.type, fr.description);
							}
						}
					}
					if(data == null) {
						debug("couldn't extract data for %s\n", fr.description);
						continue;
					}
					/*uint8[] buf = new uint8[data.length*8];
					size_t bytes = 0;
					size_t read = 0;
					charset.convert(data.data, buf, ConverterFlags.NONE, out bytes, out read);
					data = (string) buf;*/
					data = Default.escape_string(data);
					if (fr.description.contains ("Band") || fr.description.contains ("performer")) {
						artist = data;
					}
					else if (fr.description.contains ("Title")) {
						title = data;
					}
					else if (fr.description.contains ("Album")) {
						album = data;
					}
					else {
						debug("frame %s\n", fr.description);
					}
				}
				f.close ();
#endif
				string standard_output;
				string standard_error;
				int exit_status;
				var ffprobe_call = Process.spawn_sync (null, {"ffprobe", file}, null, SpawnFlags.SEARCH_PATH, null, out standard_output, out standard_error, out exit_status);
				assert(exit_status == 0);
				foreach(var line in standard_error.split("\n")) {
					if(line.strip().has_prefix("title ")) {
						title = line.split(":")[1].strip ();
					}
					else if(line.strip().has_prefix("album ")) {
						album = line.split(":")[1].strip ();
					}
					else if(line.strip().has_prefix("artist ")) {
						artist = line.split(":")[1].strip ();
					}
					else if(line.strip().has_prefix("track ")) {
						track = int.parse(line.split(":")[1].split("/")[0]);
						if (line.split(":")[1].split("/").length > 1) {
							track_count = int.parse(line.split(":")[1].split("/")[1]);
						}
					} else if(line.strip().has_prefix("Duration:")) {
						string[] times = line.strip().replace("Duration:", "").split(",")[0].strip().split(":");
						duration = int.parse(times[0])*3600*1000 + int.parse(times[1]) * 60 * 1000 + (uint)double.parse(times[2])*1000;
					}
				}
				title = Default.escape_string(title);
				artist = Default.escape_string(artist);
				album = Default.escape_string(album);
				//stdout.printf("%s from %s by %s, %d during %u\n", title, album, artist, track, duration);
			}

			public void save () {
				artist_row = linker.get_artist_row (artist, item_pid);
				artist = artist_row.name;

				album = album ?? "Unknown";
				album_pid = linker.get_album_id (album, artist_row.pid);
				if (album_pid == null) {
					album_pid = item_pid;
					add_album ();
				}
				title = title ?? "Unknown";
				artist_row.register_album (album_pid);

				add_avformat ();

				linker.run_query_library(@"insert into item (\"pid\", \"revision_level\", \"media_kind\", \"is_song\", \"is_audio_book\", \"is_music_video\", \"is_movie\", \"is_tv_show\", \"is_home_video\", \"is_ringtone\", \"is_tone\", \"is_voice_memo\", \"is_book\", \"is_rental\", \"is_itunes_u\", \"is_digital_booklet\", \"is_podcast\", \"date_modified\", \"year\", \"content_rating\", \"content_rating_level\", \"is_compilation\", \"is_user_disabled\", \"remember_bookmark\", \"exclude_from_shuffle\", \"part_of_gapless_album\", \"chosen_by_auto_fill\", \"artwork_status\", \"artwork_cache_id\", \"start_time_ms\", \"stop_time_ms\", \"total_time_ms\", \"total_burn_time_ms\", \"track_number\", \"track_count\", \"disc_number\", \"disc_count\", \"bpm\", \"relative_volume\", \"eq_preset\", \"radio_stream_status\", \"genius_id\", \"genre_id\", \"category_id\", \"album_pid\", \"artist_pid\", \"composer_pid\", \"title\", \"artist\", \"album\", \"album_artist\", \"composer\", \"sort_title\", \"sort_artist\", \"sort_album\", \"sort_album_artist\", \"sort_composer\", \"title_order\", \"artist_order\", \"album_order\", \"genre_order\", \"composer_order\", \"album_artist_order\", \"album_by_artist_order\", \"series_name_order\", \"comment\", \"grouping\", \"description\", \"description_long\", \"collection_description\", \"copyright\", \"track_artist_pid\", \"physical_order\", \"has_lyrics\", \"date_released\") values ('$item_pid', NULL, '1', '1', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '460388824', '2015', '0', '0', '0', '0', '0', '0', '0', '0', '0', '100', '0', '0', '$duration', '0', $track, '$track_count', '0', '0', '0', '0', NULL, NULL, '0', '1', '0', '$album_pid', '$(artist_row.pid)', '1', '$title', '$artist', '$album', NULL, '$artist', '$title', '$artist', '$album', NULL, '$artist', '100', '100', '100', '100', '100', '100', NULL, '100', '', NULL, NULL, NULL, NULL, NULL, '$(artist_row.track_artist_id)', '0', '0', '0')");

				stdout.printf("Added %s of %s\n", title, artist);
			}

			public void add_album () {
				linker.run_query_library (@"insert into album (\"pid\", \"kind\", \"artwork_status\", \"artwork_item_pid\", \"artist_pid\", \"user_rating\", \"name\", \"name_order\", \"all_compilations\", \"feed_url\", \"season_number\", \"is_unknown\", \"has_songs\", \"has_music_videos\", \"sort_order\", \"artist_order\", \"has_any_compilations\", \"sort_name\", \"artist_count_calc\", \"has_movies\", \"item_count\", \"min_volume_normalization_energy\") values ('$album_pid', '2', '0', '0', '$(artist_row.pid)', '0', '$album', '100', '0', NULL, '0', '0', '1', '0', '100', '100', '0', '$album', '1', '0', '1', '0')");

			}

			public void add_avformat () {
				var duration_avformat = (duration + 1000) * 44100/1000;
				linker.run_query_library(@"insert into avformat_info (\"item_pid\", \"sub_id\", \"audio_format\", \"bit_rate\", \"channels\", \"sample_rate\", \"duration\", \"gapless_heuristic_info\", \"gapless_encoding_delay\", \"gapless_encoding_drain\", \"gapless_last_frame_resynch\", \"analysis_inhibit_flags\", \"audio_fingerprint\", \"volume_normalization_energy\") values ('$item_pid', '0', '301', '181', '0', '44100', '$duration_avformat', '33554435', '528', '1764', '5138692', '0', '0', '0')");

			}
		}
        
		/**
		 * An item is a track, a row in the Library.itdb::item table.
		 * A location is a line in the Locations.itdb::location table.
		 **/
        class ItemLocationLinker : Object {
            public DataBase locations;
            public DataBase library;

			string basis;

			Gee.ArrayList<ArtistRow> artists;

			construct {
				artists = new Gee.ArrayList<ArtistRow> ();
			}
            
            public ItemLocationLinker (string basis) {
				this.basis = basis;
                locations = new DataBase();
				locations.filename = basis + "/iPod_Control/iTunes/iTunes Library.itlp/" + "Locations.itdb";
				library = new DataBase();
				library.filename = basis + "/iPod_Control/iTunes/iTunes Library.itlp/" + "Library.itdb";

            }

			public ArtistRow get_artist_row (string? name, string default_id) {
				foreach (var artist_row in artists) {
					if (artist_row.name == name) {
						return artist_row;
					}
				}

				name = name ?? "Unknown";

				var artist_row = new ArtistRow.with_linker (this, name, default_id, get_available_track_artist_id ());
				artists.add (artist_row);
				return artist_row;
			}

			void load_artists () throws Error
				requires (library.cnn.is_opened()) {

				var q = new SelectQuery();
				q.table = "artist";
				q.connection = library.cnn;
				
				var m = q.get_table_contents();
				
				var iterator = m.create_iter ();
				
				while (iterator.move_next ()) {
					string pid = iterator.get_value_for_field ("pid").get_int64 ().to_string ();
					string name_order = iterator.get_value_for_field ("name_order").get_int64 ().to_string ();
					string name = iterator.get_value_for_field ("name").get_string ();
					int album_count = (int)iterator.get_value_for_field ("album_count").get_int64 ();
					int64 track_artist_id = get_available_track_artist_id ();
					var artist_row = new ArtistRow.full (this, pid, track_artist_id, name_order, name, album_count);
					stdout.printf("Load artist %s…\n", name);
					artists.add (artist_row);
				}
			}

			static int compare_artist (ArtistRow a, ArtistRow b) {
				return strcmp(a.name, b.name);
			}

			void save_artists () {
				artists.sort (compare_artist);
				int i = 100;
				foreach (var artist_row in artists) {
					artist_row.assign_order (i.to_string ());
					artist_row.save_to_database ();
					i += 100;
				}
			}

			struct Album {
				string pid;
				string name;
			}

			static int compare_album(Album? a, Album? b) {
				return strcmp(a.name, b.name);
			}
			
			void save_album () {
				var q = new SelectQuery();
				q.table = "album";
				q.field = "pid, name";
				q.connection = library.cnn;
				
				var m = q.get_table_contents();
				
				var iterator = m.create_iter ();

				var albums = new Gee.ArrayList<Album?>();
				
				while (iterator.move_next ()) {
					string pid = iterator.get_value_for_field ("pid").get_int64 ().to_string ();
					string name = iterator.get_value_for_field ("name").get_string ();

					var al = Album();
					al.pid = pid;
					al.name = name;
					albums.add(al);
				}

				albums.sort (compare_album);
				int i = 100;
				foreach (var al in albums) {
					run_query_library (@"update album set name_order = $i where pid = $(al.pid)");
					run_query_library (@"update album set sort_order = $i where pid = $(al.pid)");
					i += 100;
				}
			}


			int64 available_track_artist_id = 1;

			public int64 get_available_track_artist_id () {
				// yep, don't want to find out if I have to do a++ or ++a or whatever
				available_track_artist_id++;
				return available_track_artist_id - 1;
			}

			public void run_query_library (string query) {
				library.run_query(query);
			}
            
            public void open_dbs () throws Error {
                /* Opening and initializing DB */
				// TODO: handle errors
				locations.open();
				library.open();
				load_artists ();
				clear_track_artist ();
            }

			// does not remove files atm
			public void clear_library () {
                var q = new ClearQuery ();
				q.connection = library.cnn;
				q.table = "item_to_container";
				q.clear_table ();
				q.table = "item";
				q.clear_table ();
				q.table = "artist";
				q.clear_table ();
				q.table = "album";
				q.clear_table ();
				q.table = "track_artist";
				q.clear_table ();
				q.table = "avformat_info";
				q.clear_table ();

				artists.clear ();
			}

			public void clear_track_artist () {
                var q = new ClearQuery ();
				q.connection = library.cnn;
				q.table = "track_artist";
				q.clear_table ();
			}
            
            public void print_locations_content () throws Error
				requires (locations.cnn.is_opened()) {
                var q = new SelectQuery();
                q.table = "location";
                q.connection = locations.cnn;
                
                /* Select * from test */
                this.show_data(q);
            }
            
            public void show_data (SelectQuery q) 
                throws Error 
                requires (locations.cnn.is_opened())
            {
                try {
                    var m = q.get_table_contents();
                    stdout.printf("Table: '%s'\n%s", q.table, m.dump_as_string());
                }
                catch  (GLib.Error e){
                    stdout.printf("ERROR: '%s'\n", e.message);
                }
            }

			public List<string> get_available_locations () {
                var q = new SelectQuery();
                q.table = "location";
                q.connection = locations.cnn;
                
				//TODO: handle errors
				var m = q.get_table_contents();

				var iterator = m.create_iter ();

				var available_locations_list = new List<string> ();

				while (iterator.move_next ()) {
					available_locations_list.append (iterator.get_value_for_field ("location").get_string ());
				}
				return available_locations_list;
			}

			DataModelIter? unused_iterator = null;
			DataModel? unused_datamodel = null;

			public string? peek_unused_location_id () {

				if(unused_datamodel == null) {
					var q = new SelectQuery();
					q.table = "location";
					q.field = "item_pid";
					q.connection = locations.cnn;
					
					//TODO: handle errors
					unused_datamodel = q.get_table_contents();

					unused_iterator = unused_datamodel.create_iter ();
				}

				while (unused_iterator.move_next ()) {
					string current_id = unused_iterator.get_value_for_field ("item_pid").get_int64 ().to_string ();
					var checker = new SelectQueryPid ();
					checker.table = "item";
					checker.pid = current_id;
					checker.connection = library.cnn;
					
					//TODO: handle errors
					var return_library = checker.get_table_contents();

					var iterator_library = return_library.create_iter ();

					if(!iterator_library.move_next ()) {
						return current_id;
					}
				}
				error ("No ids available, nothing left to do but cry.");
				return null;
			}

			public string? get_artist_id (string artist) {
                var b = new Gda.SqlBuilder(Gda.SqlStatementType.SELECT);

                b.select_add_field ("pid", null, null);
				b.select_add_target("artist", null);

				var cond_id = b.add_cond(Gda.SqlOperatorType.EQ, b.add_field_id ("name", "artist"), b.add_expr_value(null, artist), 0);
				b.set_where(cond_id);
				var s = b.get_statement();
				var m = library.cnn.statement_execute_select(s, null);
				var iterator = m.create_iter ();
				if(iterator.move_next ()) {
					return iterator.get_value_for_field ("pid").get_int64 ().to_string ();
				}
				else {
					return null;
				}
			}
			
			public string? get_album_id (string album, string artist_pid) {
                var b = new Gda.SqlBuilder(Gda.SqlStatementType.SELECT);

                b.select_add_field ("pid", null, null);
				b.select_add_target("album", null);

				var cond_id2 = b.add_cond(Gda.SqlOperatorType.EQ, b.add_field_id ("name", "album"), b.add_expr_value(null, Default.unescape_string(album)), 0);
				var cond_id1 = b.add_cond(Gda.SqlOperatorType.EQ, b.add_field_id ("artist_pid", "album"), b.add_expr_value(null, artist_pid), 0);
				var cond_id = b.add_cond(Gda.SqlOperatorType.AND, cond_id2, cond_id1, 0);
				b.set_where(cond_id);
				var s = b.get_statement();
				var m = library.cnn.statement_execute_select(s, null);
				var iterator = m.create_iter ();
				if(iterator.move_next ()) {
					return iterator.get_value_for_field ("pid").get_int64 ().to_string ();
				}
				else {
					return null;
				}
			}


			public string? filename_for_id (string id) {
                var q = new SelectQueryPid ();
                q.table = "location";
				q.pid = id;
				q.field_pid = "item_pid";
                q.connection = locations.cnn;
                
				//TODO: handle errors
				var m = q.get_table_contents();

				var iterator = m.create_iter ();

				iterator.move_next ();
				return iterator.get_value_for_field ("location").get_string ();
			}

			public void print_library_content () throws Error
				requires (library.cnn.is_opened()) {
                var q = new SelectQuery();
                q.table = "item";
                q.connection = library.cnn;
                
                /* Select * from test */
                this.show_data(q);
            }
			
			public void add_folder (File file, Cancellable? cancellable = null) throws Error {
				FileEnumerator enumerator = file.enumerate_children (
					"standard::*",
					FileQueryInfoFlags.NOFOLLOW_SYMLINKS, 
					cancellable);

				FileInfo info = null;
				while (cancellable.is_cancelled () == false && ((info = enumerator.next_file (cancellable)) != null)) {
					if (info.get_file_type () == FileType.DIRECTORY) {
						File subdir = file.resolve_relative_path (info.get_name ());
						add_folder (subdir, cancellable);
					} else {
						File file_to_add = file.resolve_relative_path (info.get_name ());
						if(file_to_add.get_path ().has_suffix(".mp3") || file_to_add.get_path ().has_suffix (".m4a")) {
							add_file (file_to_add.get_path ());
						}
					}
				}

				if (cancellable.is_cancelled ()) {
					throw new IOError.CANCELLED ("Operation was cancelled");
				}
			}

			public void add_file (string path) {
				string basename = path.split("/")[path.split("/").length-1];
				var loc_row = new LocationRow.create_with_linker (this, basename);
				if (path.has_suffix("mp3")) {
					loc_row.copy_file (basis, path);
				} else if (path.has_suffix("m4a")) {
					var tmp_mp3_file = "/tmp/ipod7sync_tmp.mp3";
					int exit_status = 0;
					stdout.printf("Need to encode first…\n");
					var ffmpeg_call = Process.spawn_sync (null, {"ffmpeg", "-y", "-i", path, "-acodec", "libmp3lame", "-ab", "128k", tmp_mp3_file}, null, SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL, null, null, null, out exit_status);
					//var ffmpeg_call = Process.spawn_sync (null, {"ffmpeg", "-y", "-i", path, "-acodec", "libmp3lame", "-ab", "128k", tmp_mp3_file}, null, SpawnFlags.SEARCH_PATH, null, null, null, out exit_status);
					assert(exit_status == 0);
					loc_row.copy_file (basis, tmp_mp3_file);
					
				} else {
					error ("file not recognized");
				}
				loc_row.load_id3_tags(path);
				loc_row.save ();
			}

						
            public static int main (string[] args) {
                var a = new ItemLocationLinker (args[1]);
				//TODO: handle errors
				a.open_dbs();

				switch (args[2]) {
				case "clear":
					a.clear_library ();
					break;
				case "add":
					a.add_file (args[3]);
					a.save_artists ();
					a.save_album ();
					break;
				case "adddir":
					a.add_folder (File.new_for_commandline_arg (args[3]));
					a.save_artists ();
					a.save_album ();
					break;
				case "available":
					foreach (var s in a.get_available_locations ()) {
						stdout.printf("%s\n", s);
					}
					break;
				case "print":
					a.print_locations_content ();
					break;
				case "see":
					a.print_library_content ();
					break;
				case "artwork":
					var art = new ArtworkDB("/tmp/ADB");

					art.add_thumb ("F1010");
					art.add_thumb ("F1010");

					stdout.printf("%d\n", art.compute_size ());
					art.write_to_file ();
					break;
				}
                return 0;
            }
        }
}
