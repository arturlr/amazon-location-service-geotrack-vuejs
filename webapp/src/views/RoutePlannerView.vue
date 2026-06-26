<script setup>
import { reactive, ref, computed, watch } from "vue";
import { onBeforeMount } from "vue";
import Map from "../components/Map.vue";
import Header from "../components/Header.vue";
import { useGeoStore } from "../stores/geo";

const geoStore = useGeoStore();

// Selection mode: 'start' or 'end'
const selectionMode = ref("start");

// Search inputs
const depSearch = ref("");
const destSearch = ref("");
const isLoadingDep = ref(false);
const isLoadingDest = ref(false);

const items = reactive({
  departure: [],
  destination: [],
});

// Route info
const routeCalculated = ref(false);
const routeDistance = ref(null);
const routeDuration = ref(null);

// Labels for display
const startLabel = ref("");
const endLabel = ref("");

const hasStart = computed(() => {
  return geoStore.depCoord && geoStore.depCoord.lng !== undefined;
});

const hasEnd = computed(() => {
  return geoStore.destCoord && geoStore.destCoord.lng !== undefined;
});

const canCalculateRoute = computed(() => {
  return hasStart.value && hasEnd.value;
});

// Watch for search input changes
watch(depSearch, async (newValue) => {
  if (!newValue || newValue.length < 3) {
    items.departure = [];
    return;
  }
  isLoadingDep.value = true;
  try {
    let params = {
      IndexName: import.meta.env.VITE_GEOPLACE_INDEX,
      Text: newValue,
      MaxResults: 8,
      BiasPosition: [-123.11336, 49.26038],
    };
    items.departure = await geoStore.searchPlaceIndexForText(params);
  } catch (error) {
    console.error(error);
  } finally {
    isLoadingDep.value = false;
  }
});

watch(destSearch, async (newValue) => {
  if (!newValue || newValue.length < 3) {
    items.destination = [];
    return;
  }
  isLoadingDest.value = true;
  try {
    let params = {
      IndexName: import.meta.env.VITE_GEOPLACE_INDEX,
      Text: newValue,
      MaxResults: 8,
      BiasPosition: [-123.11336, 49.26038],
    };
    items.destination = await geoStore.searchPlaceIndexForText(params);
  } catch (error) {
    console.error(error);
  } finally {
    isLoadingDest.value = false;
  }
});

function setDepCoord(val) {
  if (val && val.title) {
    let lng = val.value[0];
    let lat = val.value[1];
    geoStore.depCoord = { lng, lat };
    startLabel.value = val.title;
    routeCalculated.value = false;
  }
}

function setDestCoord(val) {
  if (val && val.title) {
    let lng = val.value[0];
    let lat = val.value[1];
    geoStore.destCoord = { lng, lat };
    endLabel.value = val.title;
    routeCalculated.value = false;
  }
}

async function calculateRoute() {
  if (!canCalculateRoute.value) return;
  try {
    let route = await geoStore.calculateRoute();
    geoStore.routeSteps = route.steps;
    geoStore.routeSummary = route.summary;
    routeDistance.value = Math.round(route.summary.Distance);
    routeDuration.value = Math.round(route.summary.DurationSeconds / 60);
    routeCalculated.value = true;
  } catch (error) {
    console.error("Error calculating route:", error);
  }
}

function clearRoute() {
  geoStore.depCoord = [];
  geoStore.destCoord = [];
  geoStore.routeSteps = [];
  geoStore.routeSummary = {};
  startLabel.value = "";
  endLabel.value = "";
  routeCalculated.value = false;
  routeDistance.value = null;
  routeDuration.value = null;
  selectionMode.value = "start";
}

function swapPoints() {
  const tempCoord = { ...geoStore.depCoord };
  const tempLabel = startLabel.value;

  geoStore.depCoord = { ...geoStore.destCoord };
  geoStore.destCoord = tempCoord;
  startLabel.value = endLabel.value;
  endLabel.value = tempLabel;
  routeCalculated.value = false;
}

// Called by Map component when user clicks on map in point-select mode
function onMapPointSelected(lngLat) {
  if (selectionMode.value === "start") {
    geoStore.depCoord = { lng: lngLat.lng, lat: lngLat.lat };
    startLabel.value = `${lngLat.lat.toFixed(5)}, ${lngLat.lng.toFixed(5)}`;
    selectionMode.value = "end";
  } else {
    geoStore.destCoord = { lng: lngLat.lng, lat: lngLat.lat };
    endLabel.value = `${lngLat.lat.toFixed(5)}, ${lngLat.lng.toFixed(5)}`;
  }
  routeCalculated.value = false;
}
</script>

<template>
  <div>
    <Header />

    <v-container>
      <v-row>
        <!-- Left Panel: Controls -->
        <v-col cols="12" md="4">
          <v-card elevation="2">
            <v-card-title class="d-flex align-center">
              <v-icon class="mr-2">mdi-map-marker-distance</v-icon>
              Route Planner
            </v-card-title>

            <v-card-subtitle class="pb-2">
              Click on the map or search to set start and end points
            </v-card-subtitle>

            <v-card-text>
              <!-- Selection Mode Toggle -->
              <v-btn-toggle v-model="selectionMode" mandatory color="primary" class="mb-4" density="compact">
                <v-btn value="start" size="small">
                  <v-icon start color="green">mdi-map-marker</v-icon>
                  Set Start
                </v-btn>
                <v-btn value="end" size="small">
                  <v-icon start color="red">mdi-map-marker</v-icon>
                  Set End
                </v-btn>
              </v-btn-toggle>

              <!-- Start Point -->
              <v-card variant="outlined" class="mb-3 pa-2">
                <div class="d-flex align-center mb-1">
                  <v-icon color="green" size="small" class="mr-1">mdi-circle</v-icon>
                  <span class="text-caption font-weight-bold">START POINT</span>
                </div>
                <v-autocomplete
                  v-model="depSearch"
                  :items="items.departure"
                  :loading="isLoadingDep"
                  @update:modelValue="setDepCoord"
                  clearable
                  hide-details
                  no-filter
                  return-object
                  density="compact"
                  variant="outlined"
                  placeholder="Search address or click map"
                  prepend-inner-icon="mdi-magnify"
                ></v-autocomplete>
                <div v-if="startLabel" class="text-caption mt-1 text-grey-darken-1">
                  <v-icon size="x-small">mdi-check-circle</v-icon>
                  {{ startLabel }}
                </div>
              </v-card>

              <!-- Swap Button -->
              <div class="text-center my-1">
                <v-btn icon size="small" variant="text" @click="swapPoints" :disabled="!hasStart || !hasEnd">
                  <v-icon>mdi-swap-vertical</v-icon>
                </v-btn>
              </div>

              <!-- End Point -->
              <v-card variant="outlined" class="mb-3 pa-2">
                <div class="d-flex align-center mb-1">
                  <v-icon color="red" size="small" class="mr-1">mdi-circle</v-icon>
                  <span class="text-caption font-weight-bold">END POINT</span>
                </div>
                <v-autocomplete
                  v-model="destSearch"
                  :items="items.destination"
                  :loading="isLoadingDest"
                  @update:modelValue="setDestCoord"
                  clearable
                  hide-details
                  no-filter
                  return-object
                  density="compact"
                  variant="outlined"
                  placeholder="Search address or click map"
                  prepend-inner-icon="mdi-magnify"
                ></v-autocomplete>
                <div v-if="endLabel" class="text-caption mt-1 text-grey-darken-1">
                  <v-icon size="x-small">mdi-check-circle</v-icon>
                  {{ endLabel }}
                </div>
              </v-card>

              <!-- Action Buttons -->
              <v-btn
                block
                color="primary"
                prepend-icon="mdi-directions"
                :disabled="!canCalculateRoute"
                @click="calculateRoute"
                class="mb-2"
              >
                Calculate Route
              </v-btn>

              <v-btn
                block
                variant="outlined"
                prepend-icon="mdi-eraser"
                @click="clearRoute"
              >
                Clear All
              </v-btn>

              <!-- Route Summary -->
              <v-expand-transition>
                <v-card v-if="routeCalculated" variant="tonal" color="blue-lighten-5" class="mt-4 pa-3">
                  <div class="text-subtitle-2 font-weight-bold mb-2">
                    <v-icon size="small" class="mr-1">mdi-information-outline</v-icon>
                    Route Summary
                  </div>
                  <v-row dense>
                    <v-col cols="6">
                      <div class="text-caption text-grey">Distance</div>
                      <div class="text-body-1 font-weight-bold">{{ routeDistance }} km</div>
                    </v-col>
                    <v-col cols="6">
                      <div class="text-caption text-grey">Duration</div>
                      <div class="text-body-1 font-weight-bold">{{ routeDuration }} min</div>
                    </v-col>
                  </v-row>
                </v-card>
              </v-expand-transition>
            </v-card-text>
          </v-card>

          <!-- Instructions Card -->
          <v-card elevation="1" class="mt-3">
            <v-card-text>
              <div class="text-subtitle-2 mb-2">
                <v-icon size="small" class="mr-1">mdi-help-circle-outline</v-icon>
                How to use
              </div>
              <v-list density="compact" class="text-caption">
                <v-list-item prepend-icon="mdi-numeric-1-circle-outline">
                  Select "Set Start" or "Set End" mode
                </v-list-item>
                <v-list-item prepend-icon="mdi-numeric-2-circle-outline">
                  Click on the map or search an address
                </v-list-item>
                <v-list-item prepend-icon="mdi-numeric-3-circle-outline">
                  Click "Calculate Route" to see the path
                </v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Right Panel: Map -->
        <v-col cols="12" md="8">
          <v-card elevation="2">
            <div class="pa-1">
              <v-chip size="small" :color="selectionMode === 'start' ? 'green' : 'red'" class="ma-1">
                <v-icon start size="small">mdi-cursor-default-click</v-icon>
                Click to set {{ selectionMode === 'start' ? 'START' : 'END' }} point
              </v-chip>
            </div>
            <Suspense>
              <Map action="point_select" @point-selected="onMapPointSelected" />
            </Suspense>
          </v-card>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>
