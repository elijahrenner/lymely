import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt

geojson_path = 'counties.geojson'
csv_path = 'lyme_disease_2022.csv'

counties = gpd.read_file(geojson_path)
counties['GEOID'] = counties['GEOID'].astype(str).str.zfill(5)
csv_data = pd.read_csv(csv_path, dtype={'GEOID': str})
csv_data['GEOID'] = csv_data['GEOID'].str.zfill(5)
merged_data = counties.merge(csv_data, on='GEOID', how='left')
missing_data = merged_data[merged_data.isna().any(axis=1)]
missing_mainland = missing_data[~missing_data['GEOID'].str.startswith('72')]
missing_non_mainland = missing_data[missing_data['GEOID'].str.startswith('72')]
print(f"Mainland USA counties with missing data:\n{missing_mainland[['GEOID', 'NAME']]}")
print(f"Non-mainland counties with missing data:\n{missing_non_mainland[['GEOID', 'NAME']]}")
output_geojson_path = 'merged_county_data.geojson'  # output path
merged_data.to_file(output_geojson_path, driver='GeoJSON')
print(f"New GeoJSON file saved at: {output_geojson_path}")
